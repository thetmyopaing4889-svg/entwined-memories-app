import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/memory.dart';

/// A read-only preview derived from a cryptographically validated Family
/// Recovery Catalog. Nothing is written to Firestore until [importMissing]
/// is explicitly invoked by the parent from the confirmation UI.
class FamilyRecoveryPreview {
  final DateTime generatedAtUtc;
  final List<Memory> memories;

  const FamilyRecoveryPreview({
    required this.generatedAtUtc,
    required this.memories,
  });

  int get memoryCount => memories.length;

  DateTime? get earliestDate {
    if (memories.isEmpty) return null;
    return memories
        .map((memory) => memory.date)
        .reduce((left, right) => left.isBefore(right) ? left : right);
  }

  DateTime? get latestDate {
    if (memories.isEmpty) return null;
    return memories
        .map((memory) => memory.date)
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }
}

class FamilyRecoveryImportResult {
  final int inserted;
  final int skippedExisting;

  const FamilyRecoveryImportResult({
    required this.inserted,
    required this.skippedExisting,
  });
}

/// Recreates only missing Firestore timeline documents from a prepared local
/// catalog. It never deletes or overwrites existing `memories` documents, and
/// it never reads or writes raw original photo/video bytes.
class FamilyRecoveryRestoreService {
  FamilyRecoveryRestoreService._();

  static const _schemaVersion = 1;
  static const _catalogKind = 'active-memory-catalog';
  static const _maxMemories = 100000;
  static const _transactionChunkSize = 100;
  static final _memories = FirebaseFirestore.instance.collection('memories');

  static Future<FamilyRecoveryPreview> previewPreparedCatalog(
    String catalogPath,
  ) async {
    final file = File(catalogPath);
    if (!await file.exists()) {
      throw StateError(
          'Prepared Recovery Catalog ကိုမတွေ့တော့ဘူး။ Restore ကိုပြန်လုပ်ပါ။');
    }
    return previewFromCatalogJson(await file.readAsString());
  }

  /// Pure parser kept public for deterministic regression tests. It rejects an
  /// invalid catalog rather than guessing fields or importing a partial result.
  static FamilyRecoveryPreview previewFromCatalogJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Recovery Catalog format is invalid.');
    }
    final root = Map<Object?, Object?>.from(decoded);
    if ((root['schemaVersion'] as num?)?.toInt() != _schemaVersion ||
        root['kind'] != _catalogKind) {
      throw const FormatException('Recovery Catalog version is not supported.');
    }
    final generatedAtUtc =
        DateTime.tryParse(root['generatedAtUtc'] as String? ?? '')?.toUtc();
    if (generatedAtUtc == null) {
      throw const FormatException('Recovery Catalog timestamp is invalid.');
    }
    final rawMemories = root['memories'];
    if (rawMemories is! List || rawMemories.length > _maxMemories) {
      throw const FormatException('Recovery Catalog post list is invalid.');
    }

    final seenIds = <String>{};
    final memories = <Memory>[];
    for (final rawMemory in rawMemories) {
      if (rawMemory is! Map) {
        throw const FormatException(
            'Recovery Catalog contains an invalid post.');
      }
      final memory =
          _memoryFromCatalogMap(Map<Object?, Object?>.from(rawMemory));
      if (!seenIds.add(memory.id)) {
        throw const FormatException(
            'Recovery Catalog contains a duplicate post ID.');
      }
      memories.add(memory);
    }
    memories.sort((left, right) => right.date.compareTo(left.date));
    return FamilyRecoveryPreview(
      generatedAtUtc: generatedAtUtc,
      memories: List<Memory>.unmodifiable(memories),
    );
  }

  /// Uses transactions to guarantee that an already-existing Memory is skipped
  /// rather than overwritten, even if Dad and Mom use the app at the same time.
  static Future<FamilyRecoveryImportResult> importMissing(
    FamilyRecoveryPreview preview,
  ) async {
    var inserted = 0;
    var skippedExisting = 0;
    for (var start = 0;
        start < preview.memories.length;
        start += _transactionChunkSize) {
      final end = (start + _transactionChunkSize).clamp(
        0,
        preview.memories.length,
      );
      final chunk = preview.memories.sublist(start, end);
      final counts =
          await FirebaseFirestore.instance.runTransaction((transaction) async {
        final references =
            chunk.map((memory) => _memories.doc(memory.id)).toList(
                  growable: false,
                );
        // Firestore transactions require every read before the first write.
        final existing = await Future.wait(
          references.map(transaction.get),
        );
        var chunkInserted = 0;
        var chunkSkipped = 0;
        for (var index = 0; index < chunk.length; index++) {
          if (existing[index].exists) {
            chunkSkipped++;
            continue;
          }
          transaction.set(references[index], chunk[index].toMap());
          chunkInserted++;
        }
        return (inserted: chunkInserted, skipped: chunkSkipped);
      });
      inserted += counts.inserted;
      skippedExisting += counts.skipped;
    }
    return FamilyRecoveryImportResult(
      inserted: inserted,
      skippedExisting: skippedExisting,
    );
  }

  static Memory _memoryFromCatalogMap(Map<Object?, Object?> data) {
    final id = (data['id'] as String? ?? '').trim();
    if (id.isEmpty || id.length > 200 || id.contains('/')) {
      throw const FormatException('Recovery Catalog post ID is invalid.');
    }
    final date = DateTime.tryParse(data['dateUtc'] as String? ?? '')?.toUtc();
    if (date == null) {
      throw const FormatException('Recovery Catalog post date is invalid.');
    }
    final rawPhotos = data['photos'];
    if (rawPhotos != null && rawPhotos is! List) {
      throw const FormatException('Recovery Catalog photo list is invalid.');
    }
    final photos = <MemoryPhoto>[];
    if (rawPhotos is List) {
      for (final rawPhoto in rawPhotos) {
        if (rawPhoto is! Map) {
          throw const FormatException('Recovery Catalog photo is invalid.');
        }
        final photo = MemoryPhoto.fromMap(
          Map<String, dynamic>.from(rawPhoto),
        );
        if (photo.hasImage) photos.add(photo);
      }
    }
    final rawVideo = data['video'];
    if (rawVideo != null && rawVideo is! Map) {
      throw const FormatException('Recovery Catalog video is invalid.');
    }
    final video = rawVideo is Map ? Map<Object?, Object?>.from(rawVideo) : null;
    final videoId = (video?['youtubeVideoId'] as String?)?.trim();
    final processingStatus = (video?['processingStatus'] as String?)?.trim();

    return Memory(
      id: id,
      note: data['note'] as String? ?? '',
      date: date,
      createdBy: data['createdBy'] as String? ?? '',
      mood: data['mood'] as String? ?? '😊',
      photos: List<MemoryPhoto>.unmodifiable(photos),
      videoId: videoId?.isEmpty ?? true ? null : videoId,
      processingStatus:
          processingStatus?.isEmpty ?? true ? null : processingStatus,
    );
  }
}

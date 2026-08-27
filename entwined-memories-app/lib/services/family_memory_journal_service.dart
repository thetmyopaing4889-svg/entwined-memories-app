import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/memory.dart';
import 'original_vault_service.dart';

/// A durable, append-only local event written outside Firebase so a family can
/// reconstruct the meaning of a Memory even if the online database is later
/// unavailable. Event files are intentionally plain JSON for future portability.
class FamilyMemoryJournalExport {
  final int eventCount;
  final DateTime generatedAtUtc;
  final List<String> files;

  const FamilyMemoryJournalExport({
    required this.eventCount,
    required this.generatedAtUtc,
    required this.files,
  });

  factory FamilyMemoryJournalExport.fromMap(Map<Object?, Object?> data) {
    final rawFiles = data['files'];
    return FamilyMemoryJournalExport(
      eventCount: (data['eventCount'] as num?)?.toInt() ?? 0,
      generatedAtUtc:
          DateTime.tryParse(data['generatedAtUtc'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      files: rawFiles is List
          ? rawFiles.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }
}

class FamilyRecoveryCatalog {
  final int memoryCount;
  final DateTime generatedAtUtc;
  final String fileName;

  const FamilyRecoveryCatalog({
    required this.memoryCount,
    required this.generatedAtUtc,
    required this.fileName,
  });
}

class PreparedFamilyRecoveryCatalog {
  final String catalogPath;
  final int memoryCount;
  final DateTime generatedAtUtc;

  const PreparedFamilyRecoveryCatalog({
    required this.catalogPath,
    required this.memoryCount,
    required this.generatedAtUtc,
  });

  factory PreparedFamilyRecoveryCatalog.fromMap(Map<Object?, Object?> data) {
    final catalogPath = data['catalogPath'] as String? ?? '';
    if (catalogPath.isEmpty) {
      throw StateError('Prepared Recovery Catalog path မရသေးဘူး။');
    }
    return PreparedFamilyRecoveryCatalog(
      catalogPath: catalogPath,
      memoryCount: (data['memoryCount'] as num?)?.toInt() ?? 0,
      generatedAtUtc:
          DateTime.tryParse(data['generatedAtUtc'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class FamilyMemoryJournalService {
  FamilyMemoryJournalService._();

  static const _channel = MethodChannel('entwined_memories/family_journal');
  static const _schemaVersion = 1;
  static const _uuid = Uuid();

  /// Opens Android's system folder picker only when a parent has not selected a
  /// shared Documents folder on this phone yet. The returned folder URI is never
  /// uploaded or written to Firestore.
  static Future<void> ensureArchiveFolderSelected() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'ensureArchiveFolderSelected',
      );
      if (result == null || result['configured'] != true) {
        throw StateError('Family Memory Journal folder ကိုမရွေးရသေးဘူး။');
      }
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'Family Memory Journal folder ရွေးမရဘူး။',
      );
    }
  }

  static Future<bool> isArchiveFolderSelected() async {
    try {
      return await _channel.invokeMethod<bool>('isArchiveFolderSelected') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Saves one immutable event file. Previous records are never overwritten or
  /// removed by this app, allowing future exports to reconstruct the timeline.
  static Future<String> appendMemoryEvent({
    required String eventType,
    required Memory memory,
    Iterable<OriginalVaultArchive> vaultArchives = const [],
    Map<String, Object?> extra = const {},
  }) async {
    final now = DateTime.now().toUtc();
    final eventId = _uuid.v4();
    final event = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'eventId': eventId,
      'eventType': eventType,
      'occurredAtUtc': now.toIso8601String(),
      'memory': _memoryMap(memory),
      'vaultArchives': vaultArchives.map(_vaultMap).toList(growable: false),
      if (extra.isNotEmpty) 'extra': extra,
    };

    final fileName = 'event_${now.microsecondsSinceEpoch}_$eventId.json';
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'appendJournalEvent',
        <String, Object?>{
          'fileName': fileName,
          'json': const JsonEncoder.withIndent('  ').convert(event),
        },
      );
      final writtenName = result?['fileName'] as String?;
      if (writtenName == null || writtenName.isEmpty) {
        throw StateError('Family Memory Journal file အတည်ပြုချက်မရဘူး။');
      }
      return writtenName;
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'Family Memory Journal ကိုမသိမ်းနိုင်ဘူး။',
      );
    }
  }

  /// Writes a current active-post catalog before creating an encrypted Journal
  /// backup. It deliberately contains post metadata only; original media bytes,
  /// passphrases and account credentials are never placed in the catalog.
  static Future<FamilyRecoveryCatalog> writeRecoveryCatalog(
    Iterable<Memory> memories,
  ) async {
    final generatedAtUtc = DateTime.now().toUtc();
    final ordered = List<Memory>.from(memories)
      ..sort((left, right) => left.id.compareTo(right.id));
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'generatedAtUtc': generatedAtUtc.toIso8601String(),
      'kind': 'active-memory-catalog',
      'memories': ordered.map(_memoryMap).toList(growable: false),
    };
    final fileName =
        'family_recovery_catalog_${generatedAtUtc.microsecondsSinceEpoch}.json';
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'writeRecoveryCatalog',
        <String, Object?>{
          'fileName': fileName,
          'json': const JsonEncoder.withIndent('  ').convert(payload),
        },
      );
      final writtenName = result?['fileName'] as String?;
      if (writtenName == null || writtenName != fileName) {
        throw StateError('Recovery Catalog file အတည်ပြုချက်မရဘူး။');
      }
      return FamilyRecoveryCatalog(
        memoryCount: ordered.length,
        generatedAtUtc: generatedAtUtc,
        fileName: writtenName,
      );
    } on PlatformException catch (error) {
      throw StateError(
          error.message ?? 'Recovery Catalog ကိုမသိမ်းနိုင်သေးဘူး။');
    }
  }

  /// Prepares the latest current-post Recovery Catalog from an already
  /// cryptographically validated restore folder. This operation does not import
  /// or modify Firestore; a later explicit user confirmation is required.
  static Future<PreparedFamilyRecoveryCatalog> prepareRestoredRecoveryCatalog(
    String restoreFolderUri,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'prepareRestoredRecoveryCatalog',
        <String, Object?>{'restoreFolderUri': restoreFolderUri},
      );
      if (result == null) {
        throw StateError('Restored Recovery Catalog response မရသေးဘူး။');
      }
      return PreparedFamilyRecoveryCatalog.fromMap(result);
    } on PlatformException catch (error) {
      throw StateError(
          error.message ?? 'Restored Recovery Catalog ကိုမဖတ်နိုင်သေးဘူး။');
    }
  }

  /// Creates a portable, human-readable export without modifying or removing
  /// any append-only event file. Parents can copy this export alongside the
  /// Journal Events folder during a future restore drill.
  static Future<FamilyMemoryJournalExport> exportPortableArchive() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'exportPortableArchive',
      );
      if (result == null) {
        throw StateError('Family Archive export response မရဘူး။');
      }
      final export = FamilyMemoryJournalExport.fromMap(result);
      if (export.files.length < 4) {
        throw StateError('Family Archive export files မပြည့်စုံပါ။');
      }
      return export;
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Family Archive export မလုပ်နိုင်ဘူး။');
    }
  }

  static Future<void> appendDeletionRequested(Memory memory) async {
    await appendMemoryEvent(
      eventType: 'memory_delete_requested',
      memory: memory,
    );
  }

  static Future<void> appendDeleted(Memory memory) async {
    await appendMemoryEvent(eventType: 'memory_deleted', memory: memory);
  }

  static Map<String, Object?> _memoryMap(Memory memory) => {
        'id': memory.id,
        'dateLocal': _dateOnly(memory.date),
        'dateUtc': memory.date.toUtc().toIso8601String(),
        'note': memory.note,
        'mood': memory.mood,
        'createdBy': memory.createdBy,
        'photos': memory.allPhotos
            .map(
              (photo) => <String, Object?>{
                'thumbnailUrl': photo.thumbnailUrl,
                'imageUrl': photo.imageUrl,
                'displayMediaKey': photo.displayMediaKey,
                'mediaProviderVersion': photo.mediaProviderVersion,
                'imagePublicId': photo.imagePublicId,
              },
            )
            .toList(growable: false),
        'video': memory.hasVideo
            ? <String, Object?>{
                'youtubeVideoId': memory.videoId,
                'processingStatus': memory.processingStatus,
              }
            : null,
      };

  static Map<String, Object?> _vaultMap(OriginalVaultArchive archive) => {
        'uri': archive.uri,
        'sha256': archive.sha256,
        'bytes': archive.bytes,
        'alreadyExisted': archive.alreadyExists,
      };

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

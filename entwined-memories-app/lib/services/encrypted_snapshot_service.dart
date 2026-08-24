import 'package:flutter/services.dart';

class EncryptedSnapshotProgress {
  final int completedFiles;
  final int totalFiles;
  final String currentPath;

  const EncryptedSnapshotProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.currentPath,
  });

  factory EncryptedSnapshotProgress.fromMap(Map<Object?, Object?> data) {
    return EncryptedSnapshotProgress(
      completedFiles: (data['completedFiles'] as num?)?.toInt() ?? 0,
      totalFiles: (data['totalFiles'] as num?)?.toInt() ?? 0,
      currentPath: data['currentPath'] as String? ?? '',
    );
  }
}

class EncryptedSnapshotResult {
  final bool created;
  final String? snapshotId;
  final int fileCount;
  final List<String> partUris;
  final DateTime createdAtUtc;
  final int incrementalAfterUtcMillis;

  const EncryptedSnapshotResult({
    required this.created,
    required this.snapshotId,
    required this.fileCount,
    required this.partUris,
    required this.createdAtUtc,
    required this.incrementalAfterUtcMillis,
  });

  factory EncryptedSnapshotResult.fromMap(Map<Object?, Object?> data) {
    final rawParts = data['parts'];
    return EncryptedSnapshotResult(
      created: data['created'] == true,
      snapshotId: data['snapshotId'] as String?,
      fileCount: (data['fileCount'] as num?)?.toInt() ?? 0,
      partUris:
          rawParts is List
              ? rawParts.whereType<String>().toList(growable: false)
              : const <String>[],
      createdAtUtc:
          DateTime.tryParse(data['createdAtUtc'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      incrementalAfterUtcMillis:
          (data['incrementalAfterUtcMillis'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Creates local encrypted archive packs only. This service never receives or
/// stores TeraBox/Telegram credentials and never stores the archive passphrase.
class EncryptedSnapshotService {
  EncryptedSnapshotService._();

  static const _channel = MethodChannel('entwined_memories/encrypted_snapshot');

  static Future<EncryptedSnapshotResult> createIncrementalSnapshot({
    required String passphrase,
    void Function(EncryptedSnapshotProgress progress)? onProgress,
  }) async {
    if (passphrase.length < 16) {
      throw StateError('Archive passphrase ကို အနည်းဆုံး ၁၆ လုံးထည့်ပါ။');
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'snapshotProgress') return null;
      final arguments = call.arguments;
      if (arguments is Map<Object?, Object?>) {
        onProgress?.call(EncryptedSnapshotProgress.fromMap(arguments));
      }
      return null;
    });

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'createIncrementalSnapshot',
        <String, Object>{'passphrase': passphrase},
      );
      if (result == null) {
        throw StateError('Encrypted backup response မရဘူး။');
      }
      return EncryptedSnapshotResult.fromMap(result);
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Encrypted backup မလုပ်နိုင်ဘူး။');
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }
}

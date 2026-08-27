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

/// Non-secret file counts shown before an off-site encrypted copy is marked as
/// ready. Journal-only packs intentionally have zero embedded originals because
/// original photo/video bytes stay in the separately synced Pictures Vault.
class EncryptedSnapshotCoverage {
  final int photos;
  final int videos;
  final int journalEvents;
  final int exports;

  const EncryptedSnapshotCoverage({
    this.photos = 0,
    this.videos = 0,
    this.journalEvents = 0,
    this.exports = 0,
  });

  int get totalOriginalMedia => photos + videos;

  factory EncryptedSnapshotCoverage.fromMap(Object? value) {
    final data = value is Map<Object?, Object?>
        ? value
        : value is Map
            ? Map<Object?, Object?>.from(value)
            : const <Object?, Object?>{};
    return EncryptedSnapshotCoverage(
      photos: (data['photos'] as num?)?.toInt() ?? 0,
      videos: (data['videos'] as num?)?.toInt() ?? 0,
      journalEvents: (data['journalEvents'] as num?)?.toInt() ?? 0,
      exports: (data['exports'] as num?)?.toInt() ?? 0,
    );
  }
}

class OriginalVaultReferenceCheck {
  final bool vaultSelected;
  final int expectedReferences;
  final int matchedReferences;
  final int missingReferences;
  final int ambiguousReferences;

  const OriginalVaultReferenceCheck({
    required this.vaultSelected,
    required this.expectedReferences,
    required this.matchedReferences,
    required this.missingReferences,
    required this.ambiguousReferences,
  });

  factory OriginalVaultReferenceCheck.fromMap(Map<Object?, Object?> data) {
    return OriginalVaultReferenceCheck(
      vaultSelected: data['vaultSelected'] == true,
      expectedReferences: (data['expectedReferences'] as num?)?.toInt() ?? 0,
      matchedReferences: (data['matchedReferences'] as num?)?.toInt() ?? 0,
      missingReferences: (data['missingReferences'] as num?)?.toInt() ?? 0,
      ambiguousReferences: (data['ambiguousReferences'] as num?)?.toInt() ?? 0,
    );
  }
}

class EncryptedSnapshotVerificationResult {
  final bool verified;
  final String snapshotId;
  final int fileCount;
  final int partCount;
  final DateTime verifiedAtUtc;

  const EncryptedSnapshotVerificationResult({
    required this.verified,
    required this.snapshotId,
    required this.fileCount,
    required this.partCount,
    required this.verifiedAtUtc,
  });

  factory EncryptedSnapshotVerificationResult.fromMap(
    Map<Object?, Object?> data,
  ) {
    return EncryptedSnapshotVerificationResult(
      verified: data['verified'] == true,
      snapshotId: data['snapshotId'] as String? ?? '',
      fileCount: (data['fileCount'] as num?)?.toInt() ?? 0,
      partCount: (data['partCount'] as num?)?.toInt() ?? 0,
      verifiedAtUtc:
          DateTime.tryParse(data['verifiedAtUtc'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class EncryptedSnapshotRestoreResult {
  final bool restored;
  final String snapshotId;
  final int fileCount;
  final int partCount;
  final String restoreFolderUri;
  final DateTime restoredAtUtc;

  const EncryptedSnapshotRestoreResult({
    required this.restored,
    required this.snapshotId,
    required this.fileCount,
    required this.partCount,
    required this.restoreFolderUri,
    required this.restoredAtUtc,
  });

  factory EncryptedSnapshotRestoreResult.fromMap(Map<Object?, Object?> data) {
    return EncryptedSnapshotRestoreResult(
      restored: data['restored'] == true,
      snapshotId: data['snapshotId'] as String? ?? '',
      fileCount: (data['fileCount'] as num?)?.toInt() ?? 0,
      partCount: (data['partCount'] as num?)?.toInt() ?? 0,
      restoreFolderUri: data['restoreFolderUri'] as String? ?? '',
      restoredAtUtc:
          DateTime.tryParse(data['restoredAtUtc'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class EncryptedSnapshotResult {
  final bool created;
  final String? snapshotId;
  final int fileCount;
  final List<String> partUris;
  final DateTime createdAtUtc;
  final String snapshotScope;
  final EncryptedSnapshotCoverage coverage;

  const EncryptedSnapshotResult({
    required this.created,
    required this.snapshotId,
    required this.fileCount,
    required this.partUris,
    required this.createdAtUtc,
    required this.snapshotScope,
    required this.coverage,
  });

  bool get isJournalOnlySnapshot => snapshotScope == 'journal-only';

  bool get isLegacySnapshot => !isJournalOnlySnapshot;

  factory EncryptedSnapshotResult.fromMap(Map<Object?, Object?> data) {
    final rawParts = data['parts'];
    return EncryptedSnapshotResult(
      created: data['created'] == true,
      snapshotId: data['snapshotId'] as String?,
      fileCount: (data['fileCount'] as num?)?.toInt() ?? 0,
      partUris: rawParts is List
          ? rawParts.whereType<String>().toList(growable: false)
          : const <String>[],
      createdAtUtc:
          DateTime.tryParse(data['createdAtUtc'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      snapshotScope: data['snapshotScope'] as String? ?? 'legacy-incremental',
      coverage: EncryptedSnapshotCoverage.fromMap(data['coverage']),
    );
  }
}

/// Creates client-side encrypted archive packs only. This service never
/// receives or stores TeraBox/Telegram credentials and never stores the
/// archive passphrase.
class EncryptedSnapshotService {
  EncryptedSnapshotService._();

  static const _channel = MethodChannel('entwined_memories/encrypted_snapshot');

  /// Lets a parent select exactly `Pictures/Entwined Memories Originals` only
  /// when they want to verify local-original availability after a restore. This
  /// is separate from Journal-only backup creation and never reads the gallery.
  static Future<void>
      ensureOriginalVaultFolderSelectedForRecoveryCheck() async {
    try {
      await _channel.invokeMethod<Object?>('ensureOriginalVaultFolderSelected');
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'Original Vault folder ကိုရွေးမရသေးဘူး။',
      );
    }
  }

  /// Returns the last native backup stage after an unexpected close. The native
  /// record contains only stage names and numeric counts; it never contains
  /// media names, paths, content, passphrases, or remote-account information.
  static Future<String?> readLatestBackupDiagnostic() async {
    try {
      final value =
          await _channel.invokeMethod<String>('readLatestBackupDiagnostic');
      return value?.trim().isEmpty ?? true ? null : value;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Checks only the selected dedicated Original Vault after archive extraction.
  /// This uses Journal SHA-256/size references and deterministic vault filenames;
  /// it does not scan the phone's gallery or read raw media contents.
  static Future<OriginalVaultReferenceCheck> checkRestoredVaultReferences(
    String restoreFolderUri,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'checkRestoredVaultReferences',
        <String, Object?>{'restoreFolderUri': restoreFolderUri},
      );
      if (result == null) {
        throw StateError('Original Vault check response မရသေးဘူး။');
      }
      return OriginalVaultReferenceCheck.fromMap(result);
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Original Vault ကိုစစ်မရသေးဘူး။');
    }
  }

  static Future<EncryptedSnapshotVerificationResult> verifyLatestSnapshot({
    required String passphrase,
  }) async {
    if (passphrase.length < 16) {
      throw StateError('Archive passphrase ကို အနည်းဆုံး ၁၆ လုံးထည့်ပါ။');
    }
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'verifyLatestSnapshot',
        <String, Object>{'passphrase': passphrase},
      );
      if (result == null) {
        throw StateError('Encrypted backup verification response မရဘူး။');
      }
      return EncryptedSnapshotVerificationResult.fromMap(result);
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Encrypted backup ကိုစစ်မရသေးဘူး။');
    }
  }

  /// Opens Android's document-tree pickers twice: first for a folder that
  /// contains all .emb parts, then for an empty/new restore destination.
  /// The native bridge checks the AES-GCM tag and ZIP manifest; if any check
  /// fails, it deletes the newly-created restore snapshot folder. It never
  /// overwrites an existing destination.
  static Future<EncryptedSnapshotRestoreResult> restoreFromSelectedFolder({
    required String passphrase,
  }) async {
    if (passphrase.length < 16) {
      throw StateError('Archive passphrase ကို အနည်းဆုံး ၁၆ လုံးထည့်ပါ။');
    }
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'restoreSnapshotFromSelectedFolder',
        <String, Object>{'passphrase': passphrase},
      );
      if (result == null) {
        throw StateError('Encrypted backup restore response မရဘူး။');
      }
      return EncryptedSnapshotRestoreResult.fromMap(result);
    } on PlatformException catch (error) {
      throw StateError(
          error.message ?? 'Encrypted backup restore မလုပ်နိုင်သေးဘူး။');
    }
  }

  /// A Journal snapshot contains the whole Family Archive tree only. It never
  /// reads, copies, compresses, or encrypts original photo/video bytes from the
  /// Pictures Vault; those originals remain protected by Syncthing local copies.
  static Future<EncryptedSnapshotResult> createJournalSnapshot({
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
        'createJournalSnapshot',
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

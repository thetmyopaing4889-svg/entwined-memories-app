import 'dart:io';

import 'package:flutter/services.dart';

/// Metadata for one original photo safely written to the shared family vault.
class OriginalVaultArchive {
  final String uri;
  final String sha256;
  final int bytes;
  final bool alreadyExists;

  const OriginalVaultArchive({
    required this.uri,
    required this.sha256,
    required this.bytes,
    required this.alreadyExists,
  });

  factory OriginalVaultArchive.fromMap(Map<Object?, Object?> data) {
    return OriginalVaultArchive(
      uri: data['uri'] as String? ?? '',
      sha256: data['sha256'] as String? ?? '',
      bytes: (data['bytes'] as num?)?.toInt() ?? 0,
      alreadyExists: data['alreadyExists'] as bool? ?? false,
    );
  }
}

/// Preserves only user-selected original images in Android shared Pictures
/// storage. This bridge never enumerates or uploads the user's whole gallery.
class OriginalVaultService {
  OriginalVaultService._();

  static const _channel = MethodChannel('entwined_memories/original_vault');

  static Future<OriginalVaultArchive> archiveSelectedPhoto({
    required File source,
    required DateTime memoryDate,
    String? mimeType,
  }) async {
    if (!await source.exists()) {
      throw StateError('ရွေးထားတဲ့မူရင်းပုံကို မဖတ်နိုင်တော့ဘူး။');
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'archiveOriginalPhoto',
        <String, Object?>{
          'sourcePath': source.path,
          'year': memoryDate.year,
          'month': memoryDate.month,
          'mimeType': mimeType,
        },
      );
      if (result == null) {
        throw StateError('Original Vault က response မပေးပါ။');
      }
      final archive = OriginalVaultArchive.fromMap(result);
      if (archive.uri.isEmpty || archive.sha256.isEmpty || archive.bytes <= 0) {
        throw StateError('Original Vault archive metadata မပြည့်စုံပါ။');
      }
      return archive;
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Original Vault ကူးမရပါ။');
    }
  }
}

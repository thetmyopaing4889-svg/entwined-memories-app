import 'dart:io';

import 'package:entwined_memories/services/original_vault_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('entwined_memories/original_vault');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('archives only the selected source with its memory month', () async {
    final source = File(
      '${Directory.systemTemp.path}/entwined-original-vault-test.jpg',
    );
    await source.writeAsBytes(<int>[1, 2, 3, 4]);
    addTearDown(() async {
      if (await source.exists()) await source.delete();
    });

    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <String, Object>{
        'uri': 'content://media/external/images/media/42',
        'sha256': List<String>.filled(64, 'a').join(),
        'bytes': 4,
        'alreadyExists': false,
      };
    });

    final archive = await OriginalVaultService.archiveSelectedPhoto(
      source: source,
      memoryDate: DateTime(2024, 2, 29),
      mimeType: 'image/jpeg',
    );

    expect(received?.method, 'archiveOriginalPhoto');
    expect(received?.arguments, <String, Object?>{
      'sourcePath': source.path,
      'year': 2024,
      'month': 2,
      'mimeType': 'image/jpeg',
    });
    expect(archive.uri, 'content://media/external/images/media/42');
    expect(archive.bytes, 4);
    expect(archive.alreadyExists, isFalse);
  });

  test('archives only the selected video with its memory month', () async {
    final source = File(
      '${Directory.systemTemp.path}/entwined-original-vault-test.mp4',
    );
    await source.writeAsBytes(<int>[5, 6, 7, 8, 9]);
    addTearDown(() async {
      if (await source.exists()) await source.delete();
    });

    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <String, Object>{
        'uri': 'content://media/external/video/media/84',
        'sha256': List<String>.filled(64, 'b').join(),
        'bytes': 5,
        'alreadyExists': false,
      };
    });

    final archive = await OriginalVaultService.archiveSelectedVideo(
      source: source,
      memoryDate: DateTime(2025, 12, 1),
      mimeType: 'video/mp4',
    );

    expect(received?.method, 'archiveOriginalVideo');
    expect(received?.arguments, <String, Object?>{
      'sourcePath': source.path,
      'year': 2025,
      'month': 12,
      'mimeType': 'video/mp4',
    });
    expect(archive.uri, 'content://media/external/video/media/84');
    expect(archive.bytes, 5);
    expect(archive.alreadyExists, isFalse);
  });

  test('does not invoke Android when the selected source is unavailable',
      () async {
    final missing = File(
      '${Directory.systemTemp.path}/entwined-original-vault-missing.jpg',
    );
    if (await missing.exists()) await missing.delete();

    await expectLater(
      OriginalVaultService.archiveSelectedPhoto(
        source: missing,
        memoryDate: DateTime(2024, 1, 1),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

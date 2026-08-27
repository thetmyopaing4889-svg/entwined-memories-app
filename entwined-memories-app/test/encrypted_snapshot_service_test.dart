import 'package:entwined_memories/services/encrypted_snapshot_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('entwined_memories/encrypted_snapshot');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  test(
    'rejects a short archive passphrase before native work begins',
    () async {
      await expectLater(
        EncryptedSnapshotService.createCompleteSnapshot(
          passphrase: 'too-short',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('requests persistent Original Vault folder selection', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return <String, Object>{'configured': true};
        });

    await EncryptedSnapshotService.ensureOriginalVaultFolderSelected();

    expect(received?.method, 'ensureOriginalVaultFolderSelected');
  });

  test('reads a privacy-safe native backup diagnostic when available', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return 'stage: writing_backup_input\\nposition: 9\\ntotalFiles: 9';
        });

    final diagnostic = await EncryptedSnapshotService.readLatestBackupDiagnostic();

    expect(received?.method, 'readLatestBackupDiagnostic');
    expect(diagnostic, contains('writing_backup_input'));
    expect(diagnostic, contains('totalFiles: 9'));
  });

  test('parses a complete originals-inclusive snapshot result', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return <String, Object>{
            'created': true,
            'snapshotId': 'snapshot_123',
            'fileCount': 7,
            'parts': <String>[
              'content://example/part001.emb',
              'content://example/part002.emb',
            ],
            'createdAtUtc': '2026-08-21T00:00:00.000Z',
            'snapshotScope': 'complete',
            'coverage': <String, int>{
              'photos': 3,
              'videos': 1,
              'journalEvents': 2,
              'exports': 1,
            },
          };
        });

    final snapshot = await EncryptedSnapshotService.createCompleteSnapshot(
      passphrase: 'correct horse battery staple',
    );

    expect(received?.method, 'createCompleteSnapshot');
    expect(received?.arguments, <String, Object>{
      'passphrase': 'correct horse battery staple',
    });
    expect(snapshot.created, isTrue);
    expect(snapshot.snapshotId, 'snapshot_123');
    expect(snapshot.isCompleteSnapshot, isTrue);
    expect(snapshot.fileCount, 7);
    expect(snapshot.partUris, hasLength(2));
    expect(snapshot.coverage.photos, 3);
    expect(snapshot.coverage.videos, 1);
    expect(snapshot.createdAtUtc, DateTime.utc(2026, 8, 21));
  });
}

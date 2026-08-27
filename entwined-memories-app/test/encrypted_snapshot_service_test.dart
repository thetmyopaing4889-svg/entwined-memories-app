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
        EncryptedSnapshotService.createJournalSnapshot(
          passphrase: 'too-short',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('requests Original Vault selection only for a recovery check', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <String, Object>{'configured': true};
    });

    await EncryptedSnapshotService
        .ensureOriginalVaultFolderSelectedForRecoveryCheck();

    expect(received?.method, 'ensureOriginalVaultFolderSelected');
  });

  test('reads a privacy-safe native backup diagnostic when available',
      () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return 'stage: writing_backup_input\\nposition: 9\\ntotalFiles: 9';
    });

    final diagnostic =
        await EncryptedSnapshotService.readLatestBackupDiagnostic();

    expect(received?.method, 'readLatestBackupDiagnostic');
    expect(diagnostic, contains('writing_backup_input'));
    expect(diagnostic, contains('totalFiles: 9'));
  });

  test('parses a Journal-only encrypted snapshot result', () async {
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
        'snapshotScope': 'journal-only',
        'coverage': <String, int>{
          'photos': 0,
          'videos': 0,
          'journalEvents': 2,
          'exports': 2,
        },
      };
    });

    final snapshot = await EncryptedSnapshotService.createJournalSnapshot(
      passphrase: 'correct horse battery staple',
    );

    expect(received?.method, 'createJournalSnapshot');
    expect(received?.arguments, <String, Object>{
      'passphrase': 'correct horse battery staple',
    });
    expect(snapshot.created, isTrue);
    expect(snapshot.snapshotId, 'snapshot_123');
    expect(snapshot.isJournalOnlySnapshot, isTrue);
    expect(snapshot.isLegacySnapshot, isFalse);
    expect(snapshot.fileCount, 7);
    expect(snapshot.partUris, hasLength(2));
    expect(snapshot.coverage.photos, 0);
    expect(snapshot.coverage.videos, 0);
    expect(snapshot.createdAtUtc, DateTime.utc(2026, 8, 21));
  });

  test('parses a dedicated Original Vault reference check', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <String, Object>{
        'vaultSelected': true,
        'expectedReferences': 4,
        'matchedReferences': 3,
        'missingReferences': 1,
        'ambiguousReferences': 0,
      };
    });

    final checked = await EncryptedSnapshotService.checkRestoredVaultReferences(
      'content://example/restore',
    );

    expect(received?.method, 'checkRestoredVaultReferences');
    expect(checked.vaultSelected, isTrue);
    expect(checked.expectedReferences, 4);
    expect(checked.matchedReferences, 3);
    expect(checked.missingReferences, 1);
  });
}

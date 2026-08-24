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
        EncryptedSnapshotService.createIncrementalSnapshot(
          passphrase: 'too-short',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('parses an encrypted incremental snapshot result', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return <String, Object>{
            'created': true,
            'snapshotId': 'snapshot_123',
            'fileCount': 7,
            'parts': <String>[
              'content://example/part001',
              'content://example/part002',
            ],
            'createdAtUtc': '2026-08-21T00:00:00.000Z',
            'incrementalAfterUtcMillis': 1000,
          };
        });

    final snapshot = await EncryptedSnapshotService.createIncrementalSnapshot(
      passphrase: 'correct horse battery staple',
    );

    expect(received?.method, 'createIncrementalSnapshot');
    expect(received?.arguments, <String, Object>{
      'passphrase': 'correct horse battery staple',
    });
    expect(snapshot.created, isTrue);
    expect(snapshot.snapshotId, 'snapshot_123');
    expect(snapshot.fileCount, 7);
    expect(snapshot.partUris, hasLength(2));
    expect(snapshot.createdAtUtc, DateTime.utc(2026, 8, 21));
    expect(snapshot.incrementalAfterUtcMillis, 1000);
  });
}

import 'package:entwined_memories/models/backup_health.dart';
import 'package:entwined_memories/services/encrypted_snapshot_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a native encrypted snapshot verification response', () {
    final result = EncryptedSnapshotVerificationResult.fromMap(
      <Object?, Object?>{
        'verified': true,
        'snapshotId': 'snapshot_123',
        'fileCount': 7,
        'partCount': 2,
        'verifiedAtUtc': '2026-08-25T01:02:03.000Z',
      },
    );

    expect(result.verified, isTrue);
    expect(result.snapshotId, 'snapshot_123');
    expect(result.fileCount, 7);
    expect(result.partCount, 2);
    expect(result.verifiedAtUtc, DateTime.utc(2026, 8, 25, 1, 2, 3));
  });

  test('parses restore result without exposing passphrase or cloud credentials',
      () {
    final result = EncryptedSnapshotRestoreResult.fromMap(
      <Object?, Object?>{
        'restored': true,
        'snapshotId': 'snapshot_123',
        'fileCount': 7,
        'partCount': 2,
        'restoreFolderUri': 'content://example/restore',
        'restoredAtUtc': '2026-08-25T01:02:03.000Z',
      },
    );
    final health = BackupHealthStatus.fromFirestoreMap(
      <String, Object>{
        'latestSnapshotId': result.snapshotId,
        'latestSnapshotFileCount': result.fileCount,
        // Deliberately unexpected sensitive data is ignored by the typed
        // shared-health model and has no place in its public API.
        'archivePassphrase': 'must-not-be-persisted',
        'teraBoxPassword': 'must-not-be-persisted',
      },
    );

    expect(result.restored, isTrue);
    expect(result.restoreFolderUri, 'content://example/restore');
    expect(health.latestSnapshotId, 'snapshot_123');
    expect(health.latestSnapshotFileCount, 7);
    expect(health.hasSnapshot, isFalse);
  });
}

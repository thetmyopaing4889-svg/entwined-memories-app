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

  test('parses complete snapshot coverage without exposing filenames or secrets', () {
    final result = EncryptedSnapshotResult.fromMap(<Object?, Object?>{
      'created': true,
      'snapshotId': 'snapshot_456',
      'fileCount': 15,
      'parts': <String>['content://example/part001.emb'],
      'createdAtUtc': '2026-08-26T12:00:00.000Z',
      'snapshotScope': 'complete',
      'coverage': <Object?, Object?>{
        'photos': 9,
        'videos': 2,
        'journalEvents': 3,
        'exports': 1,
        'archivePassphrase': 'must-not-be-read',
      },
    });

    expect(result.isCompleteSnapshot, isTrue);
    expect(result.coverage.photos, 9);
    expect(result.coverage.videos, 2);
    expect(result.coverage.totalOriginalMedia, 11);
    expect(result.coverage.journalEvents, 3);
    expect(result.coverage.exports, 1);
  });

  test('treats an older snapshot response as non-complete', () {
    final result = EncryptedSnapshotResult.fromMap(<Object?, Object?>{
      'created': true,
      'snapshotId': 'snapshot_legacy',
      'fileCount': 10,
      'parts': <String>['content://example/part001.emb'],
      'createdAtUtc': '2026-08-26T12:00:00.000Z',
    });

    expect(result.isCompleteSnapshot, isFalse);
    expect(result.coverage.totalOriginalMedia, 0);
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

import 'package:entwined_memories/models/backup_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupHealthStatus', () {
    test('sixMonthsAfter uses calendar months and clamps leap-month days', () {
      final due = BackupHealthStatus.sixMonthsAfter(
        DateTime.utc(2028, 8, 31, 9, 30),
      );

      expect(due, DateTime.utc(2029, 2, 28, 9, 30));
    });

    test('reads only shared non-secret completion fields', () {
      final health = BackupHealthStatus.fromFirestoreMap(<String, Object>{
        'latestSnapshotId': 'snapshot_123',
        'latestSnapshotCreatedAtUtc': '2026-08-25T00:00:00.000Z',
        'latestSnapshotFileCount': 4,
        'latestSnapshotPartCount': 1,
        'latestSnapshotCreatedBy': 'Dad',
        'nextHealthCheckDueAtUtc': '2027-02-25T00:00:00.000Z',
      });

      expect(health.hasSnapshot, isTrue);
      expect(health.latestSnapshotId, 'snapshot_123');
      expect(health.latestSnapshotFileCount, 4);
      expect(health.latestSnapshotPartCount, 1);
      expect(health.isDueAt(DateTime.utc(2027, 2, 24, 23, 59)), isFalse);
      expect(health.isDueAt(DateTime.utc(2027, 2, 25)), isTrue);
    });
  });
}

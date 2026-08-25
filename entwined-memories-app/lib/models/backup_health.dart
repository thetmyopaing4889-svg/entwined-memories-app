import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared, non-secret family backup-health state stored in
/// `app_data/settings.backupHealth`.
///
/// It intentionally contains only timestamps, snapshot metadata and the
/// parent-provided creator label. Archive passphrases, TeraBox credentials and
/// Telegram credentials must never be placed in this model or in Firestore.
class BackupHealthStatus {
  static const int schemaVersion = 1;

  final String? latestSnapshotId;
  final DateTime? latestSnapshotCreatedAtUtc;
  final int latestSnapshotFileCount;
  final int latestSnapshotPartCount;
  final String? latestSnapshotCreatedBy;
  final DateTime? latestVerifiedAtUtc;
  final String? latestVerifiedBy;
  final DateTime? lastRestoreDrillAtUtc;
  final String? lastRestoreDrillBy;
  final DateTime? teraBoxCheckedAtUtc;
  final String? teraBoxCheckedBy;
  final DateTime? telegramCheckedAtUtc;
  final String? telegramCheckedBy;
  final DateTime? nextHealthCheckDueAtUtc;
  final String? note;

  const BackupHealthStatus({
    this.latestSnapshotId,
    this.latestSnapshotCreatedAtUtc,
    this.latestSnapshotFileCount = 0,
    this.latestSnapshotPartCount = 0,
    this.latestSnapshotCreatedBy,
    this.latestVerifiedAtUtc,
    this.latestVerifiedBy,
    this.lastRestoreDrillAtUtc,
    this.lastRestoreDrillBy,
    this.teraBoxCheckedAtUtc,
    this.teraBoxCheckedBy,
    this.telegramCheckedAtUtc,
    this.telegramCheckedBy,
    this.nextHealthCheckDueAtUtc,
    this.note,
  });

  factory BackupHealthStatus.fromFirestoreMap(Object? value) {
    final raw = value is Map ? Map<Object?, Object?>.from(value) : const {};
    return BackupHealthStatus(
      latestSnapshotId: _cleanString(raw['latestSnapshotId']),
      latestSnapshotCreatedAtUtc: _asUtc(raw['latestSnapshotCreatedAtUtc']),
      latestSnapshotFileCount: _asInt(raw['latestSnapshotFileCount']),
      latestSnapshotPartCount: _asInt(raw['latestSnapshotPartCount']),
      latestSnapshotCreatedBy: _cleanString(raw['latestSnapshotCreatedBy']),
      latestVerifiedAtUtc: _asUtc(raw['latestVerifiedAtUtc']),
      latestVerifiedBy: _cleanString(raw['latestVerifiedBy']),
      lastRestoreDrillAtUtc: _asUtc(raw['lastRestoreDrillAtUtc']),
      lastRestoreDrillBy: _cleanString(raw['lastRestoreDrillBy']),
      teraBoxCheckedAtUtc: _asUtc(raw['teraBoxCheckedAtUtc']),
      teraBoxCheckedBy: _cleanString(raw['teraBoxCheckedBy']),
      telegramCheckedAtUtc: _asUtc(raw['telegramCheckedAtUtc']),
      telegramCheckedBy: _cleanString(raw['telegramCheckedBy']),
      nextHealthCheckDueAtUtc: _asUtc(raw['nextHealthCheckDueAtUtc']),
      note: _cleanString(raw['note']),
    );
  }

  bool get hasSnapshot =>
      latestSnapshotId != null && latestSnapshotCreatedAtUtc != null;

  bool isDueAt(DateTime now) {
    final dueAt = nextHealthCheckDueAtUtc;
    return dueAt != null && !dueAt.isAfter(now.toUtc());
  }

  /// Returns a date six calendar months after [from], retaining the time and
  /// safely clamping dates such as 31 August to the last day of February.
  static DateTime sixMonthsAfter(DateTime from) {
    final utc = from.toUtc();
    final monthIndex = utc.month - 1 + 6;
    final year = utc.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfMonth = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(
      year,
      month,
      utc.day.clamp(1, lastDayOfMonth),
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
  }

  static DateTime? _asUtc(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static String? _cleanString(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}

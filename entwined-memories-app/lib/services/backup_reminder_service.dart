import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// An Android-only local reminder for the family backup health check.
///
/// The due date is shared through Firestore, but notification permission and
/// the pending Android alarm are intentionally local to each parent's phone.
/// This service has no network calls and never receives archive credentials or
/// passphrases.
class BackupReminderService {
  BackupReminderService._();

  static const int _notificationId = 620031;
  static const String _channelId = 'family_backup_health';
  static const String _channelName = 'Family Backup Health';
  static const String _channelDescription =
      'Six-month encrypted backup health reminders';
  static const String _enabledPreferenceKey =
      'entwined_family_backup_reminder_enabled';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(initializationSettings);
    _initialized = true;
  }

  /// Requests Android 13+ notification permission only from an explicit
  /// Settings action, then schedules one inexact, battery-friendly reminder.
  /// Returns false when notifications are disabled or declined.
  static Future<bool> requestPermissionAndSchedule(DateTime dueAtUtc) async {
    await _initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    if (granted == false) return false;
    final enabled = await android?.areNotificationsEnabled();
    if (enabled == false) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPreferenceKey, true);
    await scheduleDueDate(dueAtUtc);
    return true;
  }

  /// Updates a previously parent-enabled reminder without showing a permission
  /// prompt or enabling notifications on a second phone by surprise.
  static Future<void> rescheduleIfEnabled(DateTime dueAtUtc) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledPreferenceKey) != true) return;
    await scheduleDueDate(dueAtUtc);
  }

  /// Replaces this phone's previous health reminder with the currently shared
  /// due date. Inexact delivery avoids requesting an exact-alarm permission.
  static Future<void> scheduleDueDate(DateTime dueAtUtc) async {
    await _initialize();
    await _notifications.cancel(_notificationId);
    final due = timezone.TZDateTime.from(dueAtUtc.toUtc(), timezone.UTC);
    if (!due.isAfter(timezone.TZDateTime.now(timezone.UTC))) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _notifications.zonedSchedule(
      _notificationId,
      'Family backup health check အချိန်ရောက်ပြီ',
      'Encrypted .emb files ကို TeraBox၊ Dad-only Telegram နဲ့ app ထဲမှာစစ်ဆေးပါ။',
      due,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'family-backup-health',
    );
  }

  static Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledPreferenceKey);
    await _initialize();
    await _notifications.cancel(_notificationId);
  }
}

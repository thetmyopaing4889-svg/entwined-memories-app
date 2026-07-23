import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-run onboarding story (Splash → Welcome →
/// Create Child → Parents → Creating Home → Success) has been completed
/// on this device. Deliberately local-only for now — no auth, no
/// per-user account state. If onboarding has not been completed the app
/// shows the onboarding flow; otherwise it goes straight to Home.
class OnboardingService {
  static const _completeKey = 'entwined_onboarding_complete';

  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completeKey) ?? false;
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completeKey, true);
  }
}

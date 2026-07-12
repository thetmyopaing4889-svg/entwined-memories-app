import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import 'main_screen.dart';
import 'onboarding/splash_screen.dart';
import 'onboarding/welcome_screen.dart';

/// App entry point widget.
/// Shows the Splash screen while checking local onboarding state, then
/// routes to either the onboarding story (first run) or straight to
/// Home (returning user) — per Sprint 2's "if onboarding has not been
/// completed show onboarding, otherwise go directly to Home" rule.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // Keep the splash on screen for a minimum of ~2.2s regardless of how
    // fast the local prefs check resolves, so the fade animation always
    // gets to play out. Cap the wait so a hung read never leaves the
    // user stuck on the splash forever.
    final results = await Future.wait([
      OnboardingService.isComplete().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      ),
      Future.delayed(const Duration(milliseconds: 2200)),
    ]);
    final complete = results[0] as bool;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => complete ? const MainScreen() : const WelcomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}

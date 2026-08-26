import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main_screen.dart';
import 'onboarding/splash_screen.dart';

/// App entry point. Every launch begins with the branded splash so the
/// opening animation can complete before the persisted Firebase auth state
/// decides whether to show the private family home or the sign-in screen.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();
    unawaited(_finishSplash());
  }

  Future<void> _finishSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (mounted) setState(() => _splashComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!_splashComplete) return const SplashScreen();

        // Do not temporarily keep an outgoing authenticated tree alive while
        // an Android system picker is returning. A single stable destination
        // avoids deactivating inherited dependents during that platform
        // lifecycle transition.
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _AuthLoading();
        }

        return snapshot.data == null
            ? const LoginScreen(key: ValueKey('login-screen'))
            : const MainScreen(key: ValueKey('main-screen'));
      },
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF5F7),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFE8A0B4)),
      ),
    );
  }
}

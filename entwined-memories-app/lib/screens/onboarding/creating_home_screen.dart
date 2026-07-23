import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_profile.dart';
import '../../models/parents_profile.dart';
import '../../services/profile_service.dart';
import '../../services/parents_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/onboarding_service.dart';
import 'onboarding_data.dart';
import 'success_screen.dart';

/// Screen 5 — Creating Home.
/// Uploads photos (Cloudinary only — same service AddMemoryScreen already
/// uses), saves the child + parents records to Firestore, then marks
/// onboarding complete locally before moving to the Success screen.
/// Does not touch memory/YouTube/Cloudflare logic at all.
class CreatingHomeScreen extends StatefulWidget {
  final OnboardingData data;
  const CreatingHomeScreen({super.key, required this.data});

  @override
  State<CreatingHomeScreen> createState() => _CreatingHomeScreenState();
}

class _CreatingHomeScreenState extends State<CreatingHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _error;
  String _errorSource = 'unknown';

  // Bumped manually alongside debug-visibility changes so the on-screen
  // error text always shows which build produced it.
  static const String _buildTag = '75f99e1+';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _build();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    setState(() {
      _error = null;
      _errorSource = 'unknown';
    });
    try {
      String? profilePhotoUrl;
      String? coverPhotoUrl;

      if (widget.data.profilePhoto != null) {
        debugPrint('[CreatingHome] profile photo upload: start');
        try {
          profilePhotoUrl =
              await CloudinaryService.uploadImage(widget.data.profilePhoto!)
                  .timeout(const Duration(seconds: 60));
          debugPrint(
              '[CreatingHome] profile photo upload: success ($profilePhotoUrl)');
        } catch (e) {
          debugPrint('[CreatingHome] profile photo upload: FAILED — $e');
          _errorSource = 'CreatingHomeScreen._build (profile photo upload)';
          rethrow;
        }
      }
      if (widget.data.coverPhoto != null) {
        debugPrint('[CreatingHome] cover photo upload: start');
        try {
          coverPhotoUrl =
              await CloudinaryService.uploadImage(widget.data.coverPhoto!)
                  .timeout(const Duration(seconds: 60));
          debugPrint(
              '[CreatingHome] cover photo upload: success ($coverPhotoUrl)');
        } catch (e) {
          debugPrint('[CreatingHome] cover photo upload: FAILED — $e');
          _errorSource = 'CreatingHomeScreen._build (cover photo upload)';
          rethrow;
        }
      }

      debugPrint('[CreatingHome] child profile save: start');
      try {
        await _retryOnce(
          () => ProfileService.saveProfile(ChildProfile(
            name: widget.data.childName,
            birthday: widget.data.birthday,
            photoUrl: profilePhotoUrl,
            coverPhotoUrl: coverPhotoUrl,
          )),
          timeout: const Duration(seconds: 60),
        );
        debugPrint('[CreatingHome] child profile save: success');
      } catch (e) {
        debugPrint('[CreatingHome] child profile save: FAILED after retry — $e');
        _errorSource = 'CreatingHomeScreen._build (child profile save / ProfileService.saveProfile)';
        rethrow;
      }

      debugPrint('[CreatingHome] parents save: start');
      try {
        await _retryOnce(
          () => ParentsService.saveParents(ParentsProfile(
            dadName: widget.data.dadName,
            momName: widget.data.momName,
          )),
          timeout: const Duration(seconds: 60),
        );
        debugPrint('[CreatingHome] parents save: success');
      } catch (e) {
        debugPrint('[CreatingHome] parents save: FAILED after retry — $e');
        _errorSource = 'CreatingHomeScreen._build (parents save / ParentsService.saveParents)';
        rethrow;
      }

      debugPrint('[CreatingHome] onboarding markComplete: start');
      try {
        await OnboardingService.markComplete();
        debugPrint('[CreatingHome] onboarding markComplete: success');
      } catch (e) {
        debugPrint('[CreatingHome] onboarding markComplete: FAILED — $e');
        _errorSource = 'CreatingHomeScreen._build (onboarding markComplete / OnboardingService.markComplete)';
        rethrow;
      }

      // Small pause so the loading moment always feels intentional, even
      // on a very fast connection.
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      debugPrint('[CreatingHome] navigation: start (-> SuccessScreen)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
      );
    } catch (e, stack) {
      debugPrint('[CreatingHome] _build failed: $e');
      debugPrint('[CreatingHome] stack trace:\n$stack');
      if (_errorSource == 'unknown') {
        // Thrown by something outside the per-step try/catch blocks above
        // (e.g. the post-delay navigation call itself).
        _errorSource = 'CreatingHomeScreen._build (unclassified step)';
      }
      if (!mounted) return;
      setState(() {
        _error = _debugMessageFor(e);
      });
    }
  }

  /// Runs [action] with a generous timeout, and if it fails once (timeout
  /// or any other error), tries exactly one more time before giving up.
  /// Used for the Firestore save steps, which previously had a too-short
  /// 20s timeout and no retry, so any brief connectivity hiccup surfaced
  /// as a hard failure.
  Future<T> _retryOnce<T>(
    Future<T> Function() action, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      return await action().timeout(timeout);
    } catch (e) {
      debugPrint('[CreatingHome] first attempt failed ($e) — retrying once');
      return await action().timeout(timeout);
    }
  }

  /// Debug-visible error text: always shows the build tag, which step
  /// threw, and the real exception detail — no silent generic fallback.
  /// Keeps the same on-screen widget, only the text content changes.
  String _debugMessageFor(Object e) {
    final detail = e is FirebaseException
        ? 'Firebase Error [${e.code}]: ${e.message ?? e.toString()}'
        : e.toString().replaceFirst('Exception: ', '');
    return 'Build: $_buildTag\n'
        'Error Source: $_errorSource\n'
        'Error Detail: $detail';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error == null) ...[
                RotationTransition(
                  turns: _controller,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFFE0E8),
                          Color(0xFFE8A0B4),
                          Color(0xFFFFE0E8),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFF5F7),
                        ),
                        child: const Center(
                          child: Text('❤️', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Preparing a beautiful home\nfor her memories...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF3D2C33),
                    height: 1.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                const Icon(Icons.wifi_off_rounded,
                    size: 48, color: Color(0xFFB0889A)),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF3D2C33)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _build,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ထပ်ကြိုးစားမယ်'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A0B4),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

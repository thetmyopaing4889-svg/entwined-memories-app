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
    setState(() => _error = null);
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
          rethrow;
        }
      }

      debugPrint('[CreatingHome] child profile save: start');
      try {
        await ProfileService.saveProfile(ChildProfile(
          name: widget.data.childName,
          birthday: widget.data.birthday,
          photoUrl: profilePhotoUrl,
          coverPhotoUrl: coverPhotoUrl,
        )).timeout(const Duration(seconds: 20));
        debugPrint('[CreatingHome] child profile save: success');
      } catch (e) {
        debugPrint('[CreatingHome] child profile save: FAILED — $e');
        rethrow;
      }

      debugPrint('[CreatingHome] parents save: start');
      try {
        await ParentsService.saveParents(ParentsProfile(
          dadName: widget.data.dadName,
          momName: widget.data.momName,
        )).timeout(const Duration(seconds: 20));
        debugPrint('[CreatingHome] parents save: success');
      } catch (e) {
        debugPrint('[CreatingHome] parents save: FAILED — $e');
        rethrow;
      }

      debugPrint('[CreatingHome] onboarding markComplete: start');
      try {
        await OnboardingService.markComplete();
        debugPrint('[CreatingHome] onboarding markComplete: success');
      } catch (e) {
        debugPrint('[CreatingHome] onboarding markComplete: FAILED — $e');
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
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
      });
    }
  }

  /// Turns a caught exception into a screen-appropriate message —
  /// specific detail for known exception types (Firebase, Cloudinary
  /// upload), a friendly fallback for anything else (e.g. genuine
  /// network/timeout failures). This does not change the error UI
  /// itself, only the text it displays.
  String _messageFor(Object e) {
    if (e is FirebaseException) {
      return 'Firebase Error [${e.code}]: ${e.message ?? e.toString()}';
    }
    if (e.toString().contains('Cloudinary upload')) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'မှတ်တမ်းအိမ် ပြင်ဆင်ရာမှာ အခက်အခဲရှိနေတယ်။ Network စစ်ပြီး ထပ်ကြိုးစားပါ။';
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

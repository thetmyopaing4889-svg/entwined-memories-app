import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'onboarding_data.dart';
import 'parents_screen.dart';

/// Step 4 — one question only: the cover for her memory home. Large
/// landscape preview with a soft placeholder illustration when empty.
class Step4CoverScreen extends StatefulWidget {
  final OnboardingData data;
  const Step4CoverScreen({super.key, required this.data});

  @override
  State<Step4CoverScreen> createState() => _Step4CoverScreenState();
}

class _Step4CoverScreenState extends State<Step4CoverScreen> {
  Future<void> _pick() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null && mounted) {
        setState(() => widget.data.coverPhoto = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။'),
          backgroundColor: Color(0xFFE8A0B4),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _continue() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParentsScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.data.coverPhoto;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              const Text(
                "Let's choose a beautiful cover\nfor her memory home.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3D2C33),
                  letterSpacing: -0.4,
                  height: 1.35,
                ),
              ),
              const Spacer(flex: 1),
              GestureDetector(
                onTap: _pick,
                child: Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE0E8), Color(0xFFB4C9E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    image: cover != null
                        ? DecorationImage(
                            image: FileImage(cover), fit: BoxFit.cover)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: cover == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌸', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 10),
                              Text(
                                'Tap to choose a cover',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A0B4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

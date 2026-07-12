import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'onboarding_data.dart';
import 'step4_cover_screen.dart';

/// Step 3 — one question only: her photo. Large preview, large tap
/// target — should feel like choosing a memory, not uploading a file.
class Step3PhotoScreen extends StatefulWidget {
  final OnboardingData data;
  const Step3PhotoScreen({super.key, required this.data});

  @override
  State<Step3PhotoScreen> createState() => _Step3PhotoScreenState();
}

class _Step3PhotoScreenState extends State<Step3PhotoScreen> {
  Future<void> _pick() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 900,
      );
      if (picked != null && mounted) {
        setState(() => widget.data.profilePhoto = File(picked.path));
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
      MaterialPageRoute(builder: (_) => Step4CoverScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.data.profilePhoto;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              const Text(
                "Let's choose a beautiful\nphoto of her.",
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
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE0E8), Color(0xFFFFD6E4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    image: photo != null
                        ? DecorationImage(
                            image: FileImage(photo), fit: BoxFit.cover)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8A0B4).withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: photo == null
                      ? const Center(
                          child: Icon(Icons.favorite_rounded,
                              size: 54, color: Colors.white),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                photo == null ? 'Tap to choose her photo' : 'Tap to change',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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

import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'step2_birthday_screen.dart';

/// Step 1 — one question only: her name.
class Step1NameScreen extends StatefulWidget {
  final OnboardingData data;
  const Step1NameScreen({super.key, required this.data});

  @override
  State<Step1NameScreen> createState() => _Step1NameScreenState();
}

class _Step1NameScreenState extends State<Step1NameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.data.childName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ကလေးနာမည် ရေးပါ'),
        backgroundColor: Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    widget.data.childName = name;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Step2BirthdayScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              const Text(
                "Let's begin her story.",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3D2C33),
                  letterSpacing: -0.4,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                "What's her name?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3D2C33),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFF3D2C33),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Her name',
                  hintStyle: TextStyle(color: Colors.grey[350]),
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0C4CE)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE8A0B4), width: 2),
                  ),
                ),
                onSubmitted: (_) => _continue(),
              ),
              const Spacer(flex: 3),
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

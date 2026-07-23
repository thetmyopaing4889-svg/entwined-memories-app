import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'step3_photo_screen.dart';

/// Step 2 — one question only: her birthday. Date picker only, no
/// other fields on screen.
class Step2BirthdayScreen extends StatefulWidget {
  final OnboardingData data;
  const Step2BirthdayScreen({super.key, required this.data});

  @override
  State<Step2BirthdayScreen> createState() => _Step2BirthdayScreenState();
}

class _Step2BirthdayScreenState extends State<Step2BirthdayScreen> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.data.birthday ?? DateTime.now();
  }

  void _continue() {
    widget.data.birthday = _selected;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Step3PhotoScreen(data: widget.data)),
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
              const Spacer(flex: 1),
              const Text(
                'When was she born?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3D2C33),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 220,
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          fontSize: 21,
                          color: Color(0xFF3D2C33),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _selected,
                      maximumDate: DateTime.now(),
                      minimumDate: DateTime(2000),
                      onDateTimeChanged: (d) => setState(() => _selected = d),
                    ),
                  ),
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

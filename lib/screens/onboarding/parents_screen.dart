import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'creating_home_screen.dart';

/// Screen 4 — Parents.
class ParentsScreen extends StatefulWidget {
  final OnboardingData data;
  const ParentsScreen({super.key, required this.data});

  @override
  State<ParentsScreen> createState() => _ParentsScreenState();
}

class _ParentsScreenState extends State<ParentsScreen> {
  late final TextEditingController _dadController;
  late final TextEditingController _momController;

  @override
  void initState() {
    super.initState();
    _dadController = TextEditingController(text: widget.data.dadName);
    _momController = TextEditingController(text: widget.data.momName);
  }

  @override
  void dispose() {
    _dadController.dispose();
    _momController.dispose();
    super.dispose();
  }

  void _createHome() {
    widget.data.dadName = _dadController.text.trim();
    widget.data.momName = _momController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreatingHomeScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Who will write her story?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3D2C33),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Every memory here will carry your love.',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 40),
              _label('Dad'),
              const SizedBox(height: 10),
              _field(
                controller: _dadController,
                hint: "Dad's name",
                icon: Icons.man_outlined,
              ),
              const SizedBox(height: 24),
              _label('Mom'),
              const SizedBox(height: 10),
              _field(
                controller: _momController,
                hint: "Mom's name",
                icon: Icons.woman_outlined,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A0B4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Create Memory Home',
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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3D2C33)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFFE8A0B4), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}

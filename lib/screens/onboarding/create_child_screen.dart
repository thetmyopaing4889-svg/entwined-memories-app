import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'onboarding_data.dart';
import 'parents_screen.dart';

/// Screen 3 — Create Child.
/// Not a form — the beginning of her life story. Large photo previews,
/// warm spacing.
class CreateChildScreen extends StatefulWidget {
  final OnboardingData data;
  const CreateChildScreen({super.key, required this.data});

  @override
  State<CreateChildScreen> createState() => _CreateChildScreenState();
}

class _CreateChildScreenState extends State<CreateChildScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.childName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isCover}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isCover ? 1600 : 800,
      );
      if (picked != null && mounted) {
        setState(() {
          if (isCover) {
            widget.data.coverPhoto = File(picked.path);
          } else {
            widget.data.profilePhoto = File(picked.path);
          }
        });
      }
    } catch (_) {
      if (mounted) _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.data.birthday ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: const Color(0xFFE8A0B4)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => widget.data.birthday = picked);
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('ကလေးနာမည် ရေးပါ');
      return;
    }
    widget.data.childName = name;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParentsScreen(data: widget.data)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFE8A0B4),
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Let's begin her story.",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3D2C33),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Cover Photo'),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _pickPhoto(isCover: true),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE0E8), Color(0xFFB4C9E8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          image: widget.data.coverPhoto != null
                              ? DecorationImage(
                                  image: FileImage(widget.data.coverPhoto!),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: widget.data.coverPhoto == null
                            ? const Center(
                                child: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.white,
                                    size: 36),
                              )
                            : Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Center(
                      child: GestureDetector(
                        onTap: () => _pickPhoto(isCover: false),
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFE0E8),
                                image: widget.data.profilePhoto != null
                                    ? DecorationImage(
                                        image: FileImage(
                                            widget.data.profilePhoto!),
                                        fit: BoxFit.cover)
                                    : null,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: widget.data.profilePhoto == null
                                  ? const Icon(Icons.child_care,
                                      size: 44, color: Color(0xFFE8A0B4))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE8A0B4),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Profile Photo',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500])),
                    ),
                    const SizedBox(height: 32),

                    _label('Child Name'),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Her name',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _label('Birthday'),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined,
                                color: Color(0xFFE8A0B4), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              widget.data.birthday != null
                                  ? _formatDate(widget.data.birthday!)
                                  : 'Select her birthday',
                              style: const TextStyle(
                                  fontSize: 15, color: Color(0xFF3D2C33)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
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
            ),
          ],
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
}

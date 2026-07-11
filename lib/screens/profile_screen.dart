import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/child_profile.dart';
import '../services/profile_service.dart';
import '../services/cloudinary_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  DateTime? _birthday;
  String? _photoUrl;
  File? _newPhotoFile;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileService.loadProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.name;
      _birthday = profile.birthday;
      _photoUrl = profile.photoUrl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (picked != null && mounted) {
        setState(() => _newPhotoFile = File(picked.path));
      }
    } catch (_) {
      _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime.now(),
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
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('ကလေးနာမည် ရေးပါ');
      return;
    }
    setState(() => _saving = true);
    try {
      String? finalPhotoUrl = _photoUrl;
      if (_newPhotoFile != null) {
        finalPhotoUrl = await CloudinaryService.uploadImage(_newPhotoFile!);
      }
      await ProfileService.saveProfile(ChildProfile(
        name: name,
        birthday: _birthday,
        photoUrl: finalPhotoUrl,
      ));
      if (mounted) {
        _showSnack('Profile သိမ်းပြီးပြီ ✨');
        setState(() {
          _photoUrl = finalPhotoUrl;
          _newPhotoFile = null;
        });
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  ImageProvider? get _avatarImage {
    if (_newPhotoFile != null) return FileImage(_newPhotoFile!);
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFE0E8),
                            image: _avatarImage != null
                                ? DecorationImage(
                                    image: _avatarImage!, fit: BoxFit.cover)
                                : null,
                            border: Border.all(
                                color: const Color(0xFFE8A0B4), width: 3),
                          ),
                          child: _avatarImage == null
                              ? const Icon(Icons.child_care,
                                  size: 52, color: Color(0xFFE8A0B4))
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
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _label('ကလေးနာမည်'),
                  const SizedBox(height: 8),
                  _field(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'ကလေးနာမည်',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('မွေးနေ့'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickBirthday,
                    child: _field(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined,
                                color: Color(0xFFE8A0B4), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              _birthday != null
                                  ? _formatDate(_birthday!)
                                  : 'မွေးနေ့ ရွေးပါ',
                              style: const TextStyle(
                                  fontSize: 15, color: Color(0xFF3D2C33)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A0B4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('သိမ်းမယ်',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D2C33))),
      );

  Widget _field({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

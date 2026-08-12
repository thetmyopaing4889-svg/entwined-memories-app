import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../models/child_profile.dart';
import '../services/profile_service.dart';
import '../services/cloudinary_service.dart';
import '../services/app_settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  DateTime? _birthday;
  String? _photoUrl;
  String? _coverPhotoUrl;
  ChildProfile? _loadedProfile;
  File? _newPhotoFile;
  File? _newCoverFile;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await ProfileService.loadProfile()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _loadedProfile = profile;
        _nameController.text = profile.name;
        _birthday = profile.birthday;
        _photoUrl = profile.photoUrl;
        _coverPhotoUrl = profile.coverPhotoUrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().contains('TimeoutException')
            ? 'Network တွေးနေတယ်။ Wifi/data စစ်ပြီး ထပ်ကြိုးစားပါ။'
            : 'Profile ဖွင့်မရဘူး: $e';
      });
    }
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
      if (picked == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo',
            toolbarColor: const Color(0xFFE8A0B4),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop profile photo'),
        ],
      );
      if (cropped != null && mounted) {
        setState(() => _newPhotoFile = File(cropped.path));
      }
    } catch (_) {
      _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  Future<void> _pickCoverPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop cover photo',
            toolbarColor: const Color(0xFFE8A0B4),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop cover photo'),
        ],
      );
      if (cropped != null && mounted) {
        setState(() => _newCoverFile = File(cropped.path));
      }
    } catch (_) {
      _showSnack(AppStrings.of(context).galleryError);
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
      _showSnack(AppStrings.of(context).nameRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      String? finalPhotoUrl = _photoUrl;
      String? finalCoverPhotoUrl = _coverPhotoUrl;
      if (_newPhotoFile != null) {
        finalPhotoUrl = await CloudinaryService.uploadImage(_newPhotoFile!)
            .timeout(const Duration(seconds: 60));
      }
      if (_newCoverFile != null) {
        finalCoverPhotoUrl =
            await CloudinaryService.uploadImage(_newCoverFile!)
                .timeout(const Duration(seconds: 60));
      }
      final savedProfile = ChildProfile(
        name: name,
        birthday: _birthday,
        photoUrl: finalPhotoUrl,
        coverPhotoUrl: finalCoverPhotoUrl,
        beginningTitle: _loadedProfile?.beginningTitle,
        beginningSubtitle: _loadedProfile?.beginningSubtitle,
        beginningStory: _loadedProfile?.beginningStory,
        birthPlace: _loadedProfile?.birthPlace,
        birthWeight: _loadedProfile?.birthWeight,
      );
      await ProfileService.saveProfile(savedProfile)
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        _showSnack('${AppStrings.of(context).profileSaved} ✨');
        setState(() {
          _photoUrl = finalPhotoUrl;
          _coverPhotoUrl = finalCoverPhotoUrl;
          _newPhotoFile = null;
          _newCoverFile = null;
          _loadedProfile = savedProfile;
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

  ImageProvider? get _coverImage {
    if (_newCoverFile != null) return FileImage(_newCoverFile!);
    if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty) {
      return NetworkImage(_coverPhotoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(strings.profile)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 48, color: Color(0xFFB0889A)),
                        const SizedBox(height: 16),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF3D2C33)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                            label: Text(strings.retry),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8A0B4),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickCoverPhoto,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                        image: _coverImage != null
                            ? DecorationImage(
                                image: _coverImage!, fit: BoxFit.cover)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (_coverImage == null)
                            Center(
                              child: Icon(
                                Icons.landscape_outlined,
                                size: 42,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7),
                              ),
                            ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.52),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined,
                                        size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      strings.changeCoverPhoto,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.coverPhoto,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  _label(strings.childName),
                  const SizedBox(height: 8),
                  _field(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: strings.childName,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label(strings.birthday),
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
                                  : strings.chooseBirthday,
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
                          : Text(strings.save,
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../services/youtube_service.dart';
import '../services/cloudinary_service.dart';

enum _MediaType { none, photo, video }

class AddMemoryScreen extends StatefulWidget {
  final Memory? memory;
  const AddMemoryScreen({super.key, this.memory});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _noteController = TextEditingController();
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedMood = '😊';

  File? _mediaFile;
  _MediaType _mediaType = _MediaType.none;
  String? _existingImageUrl;
  String? _existingVideoId;

  bool _isSaving = false;
  int _noteLength = 0;
  String _uploadStatus = '';

  bool get _isEditing => widget.memory != null;

  static const _moods = ['😊', '😍', '🥹', '😄', '🥰', '😌', '🎉', '💕'];
  static const int _maxNote = 500;

  @override
  void initState() {
    super.initState();
    _noteController
        .addListener(() => setState(() => _noteLength = _noteController.text.length));

    if (_isEditing) {
      final m = widget.memory!;
      _noteController.text = m.note;
      _nameController.text = m.createdBy;
      _selectedDate = m.date;
      _selectedMood = m.mood;
      _existingImageUrl = m.imageUrl;
      _existingVideoId = m.videoId;
      if (m.hasVideo) {
        _mediaType = _MediaType.video;
      } else if (m.hasImage) {
        _mediaType = _MediaType.photo;
      }
      _noteLength = m.note.length;
    } else {
      _loadSavedName();
    }
  }

  Future<void> _loadSavedName() async {
    final saved = await MemoryService.loadCreatorName();
    if (saved.isNotEmpty && mounted) {
      setState(() => _nameController.text = saved);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        setState(() {
          _mediaFile = File(picked.path);
          _mediaType = _MediaType.photo;
          _existingImageUrl = null;
          _existingVideoId = null;
        });
      }
    } catch (_) {
      if (mounted) _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 15),
      );
      if (picked != null && mounted) {
        setState(() {
          _mediaFile = File(picked.path);
          _mediaType = _MediaType.video;
          _existingImageUrl = null;
          _existingVideoId = null;
        });
      }
    } catch (_) {
      if (mounted) _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  void _removeMedia() => setState(() {
        _mediaFile = null;
        _mediaType = _MediaType.none;
        _existingImageUrl = null;
        _existingVideoId = null;
      });

  Future<void> _saveMemory() async {
    final note = _noteController.text.trim();
    final name = _nameController.text.trim();

    if (note.isEmpty) {
      _showSnack('Memory note မရေးသေးဘူး');
      return;
    }
    if (name.isEmpty) {
      _showSnack('ဘယ်သူ ထည့်တာလဲ ရေးပါ (Dad / Mom)');
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadStatus = '';
    });

    try {
      String? finalImageUrl = _existingImageUrl;
      String? finalVideoId = _existingVideoId;

      if (_mediaFile != null) {
        if (_mediaType == _MediaType.photo) {
          setState(() => _uploadStatus = 'ဓာတ်ပုံ Cloudinary ကို တင်နေတယ်...');
          finalImageUrl = await CloudinaryService.uploadImage(_mediaFile!);
          finalVideoId = null;
        } else if (_mediaType == _MediaType.video) {
          setState(
              () => _uploadStatus = 'Video YouTube ကို တင်နေတယ်...\nကြာနိုင်တယ် ခဏစောင့်ပါ 🙏');
          final dateStr =
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
          finalVideoId = await YouTubeService.uploadVideo(
            videoFile: _mediaFile!,
            title: 'Memory $dateStr',
            description: note,
          );
          finalImageUrl = null;
        }
      }

      await MemoryService.saveCreatorName(name);

      final memory = Memory(
        id: _isEditing ? widget.memory!.id : const Uuid().v4(),
        note: note,
        date: _selectedDate,
        createdBy: name,
        mood: _selectedMood,
        imageUrl: finalImageUrl,
        videoId: finalVideoId,
      );

      if (_isEditing) {
        await MemoryService.updateMemory(memory);
        if (mounted) Navigator.pop(context, true);
      } else {
        await MemoryService.addMemory(memory);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() {
        _isSaving = false;
        _uploadStatus = '';
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFE8A0B4),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: Text(_isEditing ? 'Memory ပြင်မယ်' : 'Memory အသစ်'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveMemory,
              child: const Text(
                'သိမ်းမယ်',
                style: TextStyle(
                    color: Color(0xFFE8A0B4), fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                      color: Color(0xFFE8A0B4)),
                  const SizedBox(height: 24),
                  Text(
                    _uploadStatus.isEmpty ? 'သိမ်းနေတယ်...' : _uploadStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, color: Color(0xFF3D2C33), height: 1.6),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date ──────────────────────────────────────────────
                  const _Label('နေ့ရက်'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: Color(0xFFE8A0B4), size: 18),
                        const SizedBox(width: 10),
                        Text(_formatDate(_selectedDate),
                            style: const TextStyle(
                                fontSize: 15, color: Color(0xFF3D2C33))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Mood ──────────────────────────────────────────────
                  const _Label('Mood'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods
                        .map((m) => GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMood = m),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectedMood == m
                                      ? const Color(0xFFFFD6E4)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedMood == m
                                        ? const Color(0xFFE8A0B4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(m,
                                    style:
                                        const TextStyle(fontSize: 28)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Note ──────────────────────────────────────────────
                  const _Label('Memory'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 5,
                      maxLength: _maxNote,
                      decoration: const InputDecoration(
                        hintText: 'ဒီနေ့ ဘာဖြစ်ခဲ့လဲ ရေးပါ...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Media ─────────────────────────────────────────────
                  const _Label('ဓာတ်ပုံ / Video'),
                  const SizedBox(height: 8),
                  _buildMediaSection(),
                  const SizedBox(height: 20),

                  // ── Name ──────────────────────────────────────────────
                  const _Label('ဘယ်သူ ထည့်တာလဲ'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Dad / Mom / နာမည်',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildMediaSection() {
    // Local video file selected
    if (_mediaFile != null && _mediaType == _MediaType.video) {
      return _mediaTile(
        child: Container(
          color: Colors.black87,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text('Video ရွေးပြီးပြီ',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(height: 4),
                Text('YouTube ကို upload လုပ်မယ်',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
        onRemove: _removeMedia,
      );
    }

    // Local photo selected
    if (_mediaFile != null && _mediaType == _MediaType.photo) {
      return _mediaTile(
        child: Image.file(_mediaFile!, fit: BoxFit.cover),
        onRemove: _removeMedia,
      );
    }

    // Existing YouTube video (edit mode)
    if (_existingVideoId != null) {
      return _mediaTile(
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Image.network(
              YouTubeService.getThumbnailUrl(_existingVideoId!),
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4)),
              child: const Icon(Icons.play_circle_filled,
                  color: Colors.white, size: 48),
            ),
          ],
        ),
        onRemove: _removeMedia,
      );
    }

    // Existing Cloudinary image (edit mode)
    if (_existingImageUrl != null) {
      return _mediaTile(
        child: Image.network(_existingImageUrl!, fit: BoxFit.cover),
        onRemove: _removeMedia,
      );
    }

    // Picker buttons
    return Row(
      children: [
        Expanded(
          child: _pickerBtn(
            icon: Icons.photo_library_outlined,
            label: 'ဓာတ်ပုံ',
            sub: 'Cloudinary',
            onTap: _pickPhoto,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerBtn(
            icon: Icons.videocam_outlined,
            label: 'Video',
            sub: 'YouTube',
            onTap: _pickVideo,
          ),
        ),
      ],
    );
  }

  Widget _pickerBtn({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD6E4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE8A0B4), size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D2C33))),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFB0889A))),
          ],
        ),
      ),
    );
  }

  Widget _mediaTile({required Widget child, required VoidCallback onRemove}) {
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(12), child: child),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3D2C33)),
    );
  }
}

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';

class AddMemoryScreen extends StatefulWidget {
  /// Pass an existing [memory] to enter edit mode.
  /// Leave null to create a new memory.
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

  /// Holds either a local file path (new pick) or a Firebase Storage URL
  /// (existing memory). Null = no image.
  String? _imagePath;

  bool _isSaving = false;
  int _noteLength = 0;

  bool get _isEditing => widget.memory != null;
  bool get _hasLocalFile =>
      _imagePath != null && !_imagePath!.startsWith('http');

  static const _moods = ['😊', '😍', '🥹', '😄', '🥰', '😌', '🎉', '💕'];
  static const int _maxNote = 500;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(
        () => setState(() => _noteLength = _noteController.text.length));

    if (_isEditing) {
      final m = widget.memory!;
      _noteController.text = m.note;
      _nameController.text = m.createdBy;
      _selectedDate = m.date;
      _selectedMood = m.mood;
      _imagePath = m.imageUrl; // existing Storage URL or null
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

  // ── Image handling ──────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Could not open gallery. Check app permissions.');
      }
    }
  }

  void _removeImage() => setState(() => _imagePath = null);

  /// Upload a local file to Firebase Storage and return the download URL.
  Future<String> _uploadToStorage(String localPath) async {
    final ref = FirebaseStorage.instance
        .ref('memories/${const Uuid().v4()}.jpg');
    await ref.putFile(File(localPath));
    return await ref.getDownloadURL();
  }

  // ── Date picker ─────────────────────────────────────────────────────────

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

  // ── Save / Update ───────────────────────────────────────────────────────

  Future<void> _saveMemory() async {
    final note = _noteController.text.trim();
    final name = _nameController.text.trim();

    if (note.isEmpty) {
      _showSnack('Please write something about this memory.');
      return;
    }
    if (name.isEmpty) {
      _showSnack('Please enter your name (e.g. Mom or Dad).');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Persist creator name locally
      await MemoryService.saveCreatorName(name);

      // Upload new image if user picked a local file
      String? finalImageUrl = _imagePath;
      if (_hasLocalFile) {
        finalImageUrl = await _uploadToStorage(_imagePath!);
      }

      if (_isEditing) {
        final updated = Memory(
          id: widget.memory!.id,
          note: note,
          date: _selectedDate,
          createdBy: name,
          mood: _selectedMood,
          imageUrl: finalImageUrl,
        );
        await MemoryService.updateMemory(updated);
        if (mounted) Navigator.pop(context, true);
      } else {
        final newMemory = Memory(
          id: const Uuid().v4(),
          note: note,
          date: _selectedDate,
          createdBy: name,
          mood: _selectedMood,
          imageUrl: finalImageUrl,
        );
        await MemoryService.addMemory(newMemory);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Something went wrong. Please try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Memory' : 'New Memory'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image picker ────────────────────────────────────────────
            if (_imagePath == null)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFE8A0B4), width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: Color(0xFFE8A0B4)),
                      SizedBox(height: 8),
                      Text('Add a photo',
                          style: TextStyle(
                              color: Color(0xFFB0889A),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _hasLocalFile
                        ? Image.file(
                            File(_imagePath!),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _imagePath!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 200,
                                color: const Color(0xFFFFE0E8),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFE8A0B4),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _iconBtn(Icons.edit, _pickImage),
                        const SizedBox(width: 8),
                        _iconBtn(Icons.close, _removeImage),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // ── Note ────────────────────────────────────────────────────
            const _SectionLabel(label: 'Memory note'),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 5,
              maxLength: _maxNote,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Text('$currentLength/$maxLength',
                      style: TextStyle(
                          color: currentLength >= _maxNote
                              ? Colors.redAccent
                              : const Color(0xFFB0889A),
                          fontSize: 12)),
              decoration: InputDecoration(
                hintText: 'What happened today? Write in any language…',
                hintStyle:
                    const TextStyle(color: Color(0xFFB0889A), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFFFF0F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Added by ────────────────────────────────────────────────
            const _SectionLabel(label: 'Added by'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Mom, Dad, ပါပါ, မေမေ…',
                hintStyle:
                    const TextStyle(color: Color(0xFFB0889A), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFFFF0F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Date ────────────────────────────────────────────────────
            const _SectionLabel(label: 'Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Color(0xFFE8A0B4)),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF3D2C33)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Mood ────────────────────────────────────────────────────
            const _SectionLabel(label: 'Mood'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _moods.map((mood) {
                final selected = mood == _selectedMood;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = mood),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFD6E0)
                          : const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(
                              color: const Color(0xFFE8A0B4), width: 2)
                          : null,
                    ),
                    child: Center(
                        child: Text(mood,
                            style: const TextStyle(fontSize: 26))),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // ── Save / Update button ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMemory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A0B4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditing ? 'Update Memory' : 'Save Memory',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3D2C33),
      ),
    );
  }
}

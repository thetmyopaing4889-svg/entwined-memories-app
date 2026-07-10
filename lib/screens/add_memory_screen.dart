import 'dart:io';
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
  String? _pickedImagePath;
  bool _isSaving = false;
  int _noteLength = 0;

  bool get _isEditing => widget.memory != null;

  static const _moods = ['😊', '😍', '🥹', '😄', '🥰', '😌', '🎉', '💕'];
  static const int _maxNote = 500;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(
      () => setState(() => _noteLength = _noteController.text.length),
    );

    if (_isEditing) {
      // Pre-fill all fields from existing memory
      final m = widget.memory!;
      _noteController.text = m.note;
      _nameController.text = m.createdBy;
      _selectedDate = m.date;
      _selectedMood = m.mood;
      _pickedImagePath = m.imageUrl;
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

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        setState(() => _pickedImagePath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open gallery. Check app permissions.'),
            backgroundColor: Color(0xFFE8A0B4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeImage() => setState(() => _pickedImagePath = null);

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
    await MemoryService.saveCreatorName(name);

    if (_isEditing) {
      // Update existing memory — keep the same id
      final updated = Memory(
        id: widget.memory!.id,
        note: note,
        date: _selectedDate,
        createdBy: name,
        mood: _selectedMood,
        imageUrl: _pickedImagePath,
      );
      await MemoryService.updateMemory(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      // Create new memory
      final memory = Memory(
        id: const Uuid().v4(),
        note: note,
        date: _selectedDate,
        createdBy: name,
        mood: _selectedMood,
        imageUrl: _pickedImagePath,
      );
      await MemoryService.addMemory(memory);
      if (mounted) Navigator.pop(context, memory);
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
        title: Text(_isEditing ? 'Edit Memory' : 'New Memory'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveMemory,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE8A0B4),
                      ),
                    )
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                        color: Color(0xFFE8A0B4),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ─────────────────────────────────────────────────────
            if (_pickedImagePath != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(_pickedImagePath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Change',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8EF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE8A0B4).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 38, color: Color(0xFFE8A0B4)),
                      SizedBox(height: 8),
                      Text(
                        'Add Photo (optional)',
                        style: TextStyle(
                          color: Color(0xFFB0889A),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tap to pick from gallery',
                        style: TextStyle(
                            color: Color(0xFFCCA8B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Note ──────────────────────────────────────────────────────
            const _SectionLabel(label: '📝 Memory Note'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8A0B4).withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 6,
                    maxLength: _maxNote,
                    buildCounter: (_, {required currentLength,
                            required isFocused, maxLength}) =>
                        null,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Color(0xFF3D2C33),
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'What happened today? Write your memory here...',
                      hintStyle:
                          TextStyle(color: Color(0xFFCCA8B8), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$_noteLength / $_maxNote',
                          style: TextStyle(
                            fontSize: 11,
                            color: _noteLength > 450
                                ? Colors.redAccent
                                : const Color(0xFFCCA8B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Date ──────────────────────────────────────────────────────
            const _SectionLabel(label: '📅 Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8A0B4).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFFE8A0B4), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      Memory(
                        id: '',
                        note: '',
                        date: _selectedDate,
                        createdBy: '',
                        mood: '',
                      ).formattedDate,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF3D2C33),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: Color(0xFFB0889A)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Mood ──────────────────────────────────────────────────────
            const _SectionLabel(label: '😊 Mood'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _moods.map((mood) {
                final selected = _selectedMood == mood;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFE0E8)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE8A0B4)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE8A0B4).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(mood,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Added by ──────────────────────────────────────────────────
            const _SectionLabel(label: '👤 Added by'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8A0B4).withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _nameController,
                maxLength: 30,
                buildCounter: (_, {required currentLength,
                        required isFocused, maxLength}) =>
                    null,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF3D2C33),
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. Mom, Dad, Grandma...',
                  hintStyle:
                      TextStyle(color: Color(0xFFCCA8B8), fontSize: 14),
                  prefixIcon: Icon(Icons.person_outline,
                      color: Color(0xFFE8A0B4), size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Your name is saved automatically for next time',
                style: TextStyle(fontSize: 11, color: Color(0xFFCCA8B8)),
              ),
            ),

            const SizedBox(height: 40),

            // ── Save / Update button ──────────────────────────────────────
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
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
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

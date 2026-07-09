import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';

class AddMemoryScreen extends StatefulWidget {
  const AddMemoryScreen({super.key});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedMood = '😊';
  String _selectedCreator = 'Mom';
  bool _isSaving = false;

  static const _moods = ['😊', '😍', '🥹', '😄', '🥰', '😌', '🎉', '💕'];
  static const _creators = ['Mom', 'Dad'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFFE8A0B4),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveMemory() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something about this memory.'),
          backgroundColor: Color(0xFFE8A0B4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final memory = Memory(
      id: const Uuid().v4(),
      note: note,
      date: _selectedDate,
      createdBy: _selectedCreator,
      mood: _selectedMood,
    );

    await MemoryService.addMemory(memory);

    if (mounted) {
      Navigator.pop(context, memory); // return the saved memory
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text('New Memory'),
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
                  : const Text(
                      'Save',
                      style: TextStyle(
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
            // Image placeholder (Phase 3 will add real upload)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo upload coming in Phase 3!'),
                    backgroundColor: Color(0xFFE8A0B4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8EF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE8A0B4).withOpacity(0.4),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: Color(0xFFE8A0B4)),
                    SizedBox(height: 8),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        color: Color(0xFFB0889A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '(coming soon)',
                      style: TextStyle(
                          color: Color(0xFFB0889A), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Note input
            _SectionLabel(label: '📝 Memory Note'),
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
                controller: _noteController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'What happened today? Write your memory here...',
                  hintStyle: TextStyle(color: Color(0xFFCCA8B8), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  counterStyle: TextStyle(color: Color(0xFFCCA8B8)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Date picker
            _SectionLabel(label: '📅 Date'),
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

            // Mood selector
            _SectionLabel(label: '😊 Mood'),
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

            // Created by
            _SectionLabel(label: '👤 Added by'),
            const SizedBox(height: 10),
            Row(
              children: _creators.map((creator) {
                final selected = _selectedCreator == creator;
                final color = creator == 'Mom'
                    ? const Color(0xFFFFB6C1)
                    : const Color(0xFFB4C9E8);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCreator = creator),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.25)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? color : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            creator == 'Mom'
                                ? Icons.favorite
                                : Icons.sports_soccer,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            creator,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF3D2C33)
                                  : const Color(0xFFB0889A),
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // Save button
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
                    : const Text(
                        'Save Memory',
                        style: TextStyle(
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

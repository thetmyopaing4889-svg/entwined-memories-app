class Memory {
  final String id;
  final String note;
  final String date;
  final String createdBy;
  final String mood;
  final String? imageUrl;

  Memory({
    required this.id,
    required this.note,
    required this.date,
    required this.createdBy,
    required this.mood,
    this.imageUrl,
  });
}

// Dummy data for Phase 1 testing
final List<Memory> dummyMemories = [
  Memory(
    id: '1',
    note: 'First smile today! My heart melted completely. 💕',
    date: 'July 9, 2026',
    createdBy: 'Mom',
    mood: '😍',
  ),
  Memory(
    id: '2',
    note: 'Took first steps in the living room. We were so proud!',
    date: 'June 28, 2026',
    createdBy: 'Dad',
    mood: '🥹',
  ),
  Memory(
    id: '3',
    note: 'Said "mama" for the first time this morning.',
    date: 'June 15, 2026',
    createdBy: 'Mom',
    mood: '😊',
  ),
  Memory(
    id: '4',
    note: 'Bath time giggles — the best sound in the whole world.',
    date: 'June 5, 2026',
    createdBy: 'Dad',
    mood: '😄',
  ),
  Memory(
    id: '5',
    note: 'First visit to grandma\'s house. She held the baby for hours.',
    date: 'May 20, 2026',
    createdBy: 'Mom',
    mood: '🥰',
  ),
  Memory(
    id: '6',
    note: 'Watched rain together through the window. So calm and peaceful.',
    date: 'May 10, 2026',
    createdBy: 'Dad',
    mood: '😌',
  ),
];

import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String id;
  final String note;
  final DateTime date;
  final String createdBy;
  final String mood;
  final String? imageUrl; // Firebase Storage download URL (https://...)

  Memory({
    required this.id,
    required this.note,
    required this.date,
    required this.createdBy,
    required this.mood,
    this.imageUrl,
  });

  /// Serialize to Firestore document fields
  Map<String, dynamic> toMap() => {
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'mood': mood,
        'imageUrl': imageUrl,
      };

  /// Deserialize from a Firestore document snapshot
  factory Memory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Memory(
      id: doc.id,
      note: data['note'] as String? ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
      mood: data['mood'] as String? ?? '😊',
      imageUrl: data['imageUrl'] as String?,
    );
  }

  /// Formatted date string for display
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

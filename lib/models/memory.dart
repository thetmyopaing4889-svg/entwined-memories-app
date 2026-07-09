import 'dart:convert';

class Memory {
  final String id;
  final String note;
  final DateTime date;
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'note': note,
        'date': date.toIso8601String(),
        'createdBy': createdBy,
        'mood': mood,
        'imageUrl': imageUrl,
      };

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        note: json['note'] as String,
        date: DateTime.parse(json['date'] as String),
        createdBy: json['createdBy'] as String,
        mood: json['mood'] as String,
        imageUrl: json['imageUrl'] as String?,
      );

  static List<Memory> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => Memory.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Memory> memories) {
    return jsonEncode(memories.map((m) => m.toJson()).toList());
  }

  /// Formatted date string for display
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

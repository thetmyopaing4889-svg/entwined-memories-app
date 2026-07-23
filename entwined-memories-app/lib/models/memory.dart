import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String id;
  final String note;
  final DateTime date;
  final String createdBy;
  final String mood;
  final String? imageUrl; // Cloudinary URL
  final String? videoId; // YouTube video ID
  final String? processingStatus; // processing, ready, or failed

  Memory({
    required this.id,
    required this.note,
    required this.date,
    required this.createdBy,
    required this.mood,
    this.imageUrl,
    this.videoId,
    this.processingStatus,
  });

  bool get hasVideo => videoId != null && videoId!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isVideoReady =>
      hasVideo && (processingStatus == null || processingStatus == 'ready');

  Map<String, dynamic> toMap() => {
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'mood': mood,
        'imageUrl': imageUrl,
        'videoId': videoId,
        'processingStatus': processingStatus,
      };

  factory Memory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Memory(
      id: doc.id,
      note: data['note'] as String? ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
      mood: data['mood'] as String? ?? '😊',
      imageUrl: data['imageUrl'] as String?,
      videoId: data['videoId'] as String?,
      // Existing records predate this field and already contain playable
      // video IDs, so they remain ready by default.
      processingStatus: data['processingStatus'] as String? ??
          (data['videoId'] != null ? 'ready' : null),
    );
  }

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
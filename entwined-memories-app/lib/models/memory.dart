import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String id;
  final String note;
  final DateTime date;
  final String createdBy;
  final String mood;

  /// Legacy Cloudinary URL retained so existing installations and old records
  /// continue to render while the dual-provider migration rolls out.
  final String? imageUrl;

  /// Small Cloudinary WebP used for feed thumbnails. New records also mirror
  /// this value into [imageUrl] for legacy app compatibility.
  final String? thumbnailUrl;

  /// Private R2 object key for a larger full-screen display copy. It is never a
  /// public URL and must be requested through the authenticated Worker.
  final String? displayMediaKey;
  final int? mediaProviderVersion;

  /// Cloudinary public ID used by the server-side cleanup endpoint. Older
  /// records may not have it; the Worker then performs a guarded URL fallback.
  final String? imagePublicId;
  final String? videoId; // YouTube video ID
  final String? processingStatus; // processing, ready, or failed

  Memory({
    required this.id,
    required this.note,
    required this.date,
    required this.createdBy,
    required this.mood,
    this.imageUrl,
    this.thumbnailUrl,
    this.displayMediaKey,
    this.mediaProviderVersion,
    this.imagePublicId,
    this.videoId,
    this.processingStatus,
  });

  bool get hasVideo => videoId != null && videoId!.isNotEmpty;
  bool get hasImage =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
  String? get feedThumbnailUrl => thumbnailUrl ?? imageUrl;
  bool get hasPrivateDisplay =>
      displayMediaKey != null && displayMediaKey!.isNotEmpty;
  bool get isVideoReady =>
      hasVideo && (processingStatus == null || processingStatus == 'ready');

  Map<String, dynamic> toMap() => {
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'mood': mood,
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
        'displayMediaKey': displayMediaKey,
        'mediaProviderVersion': mediaProviderVersion,
        'imagePublicId': imagePublicId,
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
      thumbnailUrl:
          data['thumbnailUrl'] as String? ?? data['imageUrl'] as String?,
      displayMediaKey: data['displayMediaKey'] as String?,
      mediaProviderVersion: (data['mediaProviderVersion'] as num?)?.toInt(),
      imagePublicId: data['imagePublicId'] as String?,
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

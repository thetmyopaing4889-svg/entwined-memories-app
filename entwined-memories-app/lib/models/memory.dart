import 'package:cloud_firestore/cloud_firestore.dart';

/// A single photo copy pair within a memory gallery.
///
/// The Cloudinary thumbnail keeps the feed quick, while [displayMediaKey]
/// identifies the private R2 copy used for full-screen viewing. Neither field
/// contains the original gallery photo from the parent's device.
class MemoryPhoto {
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? displayMediaKey;
  final int? mediaProviderVersion;
  final String? imagePublicId;

  const MemoryPhoto({
    this.imageUrl,
    this.thumbnailUrl,
    this.displayMediaKey,
    this.mediaProviderVersion,
    this.imagePublicId,
  });

  bool get hasImage =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
  String? get feedThumbnailUrl => thumbnailUrl ?? imageUrl;
  bool get hasPrivateDisplay =>
      displayMediaKey != null && displayMediaKey!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
        'displayMediaKey': displayMediaKey,
        'mediaProviderVersion': mediaProviderVersion,
        'imagePublicId': imagePublicId,
      };

  factory MemoryPhoto.fromMap(Map<String, dynamic> data) {
    return MemoryPhoto(
      imageUrl: data['imageUrl'] as String?,
      thumbnailUrl:
          data['thumbnailUrl'] as String? ?? data['imageUrl'] as String?,
      displayMediaKey: data['displayMediaKey'] as String?,
      mediaProviderVersion: (data['mediaProviderVersion'] as num?)?.toInt(),
      imagePublicId: data['imagePublicId'] as String?,
    );
  }
}

class Memory {
  final String id;
  final String note;
  final DateTime date;
  final String createdBy;
  final String mood;

  /// Legacy singular fields are retained for old app installs and existing
  /// Firestore documents. New gallery memories mirror their cover photo here.
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? displayMediaKey;
  final int? mediaProviderVersion;
  final String? imagePublicId;

  /// New gallery field. Old documents have no [photos] array and safely derive
  /// one gallery item from their legacy singular fields through [allPhotos].
  final List<MemoryPhoto> photos;

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
    this.photos = const [],
    this.videoId,
    this.processingStatus,
  });

  bool get hasVideo => videoId != null && videoId!.isNotEmpty;

  /// Gallery data for new records, or a one-item compatibility gallery for
  /// older one-photo records.
  List<MemoryPhoto> get allPhotos {
    if (photos.isNotEmpty) return List.unmodifiable(photos);
    final legacyPhoto = MemoryPhoto(
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      displayMediaKey: displayMediaKey,
      mediaProviderVersion: mediaProviderVersion,
      imagePublicId: imagePublicId,
    );
    return legacyPhoto.hasImage ? [legacyPhoto] : const [];
  }

  int get photoCount => allPhotos.length;
  MemoryPhoto? get coverPhoto => allPhotos.isEmpty ? null : allPhotos.first;
  bool get hasImage => allPhotos.isNotEmpty;
  String? get feedThumbnailUrl => coverPhoto?.feedThumbnailUrl;
  bool get hasPrivateDisplay => coverPhoto?.hasPrivateDisplay ?? false;
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
        if (photos.isNotEmpty)
          'photos': photos.map((photo) => photo.toMap()).toList(),
        'videoId': videoId,
        'processingStatus': processingStatus,
      };

  factory Memory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawPhotos = data['photos'];
    final photos = rawPhotos is List
        ? rawPhotos
            .whereType<Map>()
            .map((photo) =>
                MemoryPhoto.fromMap(Map<String, dynamic>.from(photo)))
            .where((photo) => photo.hasImage)
            .toList(growable: false)
        : const <MemoryPhoto>[];

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
      photos: photos,
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

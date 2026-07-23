import 'package:cloud_firestore/cloud_firestore.dart';

/// Single shared child profile for the whole family space.
class ChildProfile {
  final String name;
  final DateTime? birthday;
  final String? photoUrl; // Cloudinary URL
  final String? coverPhotoUrl; // Cloudinary URL, used by the Home hero cover

  const ChildProfile({
    required this.name,
    this.birthday,
    this.photoUrl,
    this.coverPhotoUrl,
  });

  static const empty = ChildProfile(name: '');

  Map<String, dynamic> toMap() => {
        'name': name,
        'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
        'photoUrl': photoUrl,
        'coverPhotoUrl': coverPhotoUrl,
      };

  factory ChildProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) return ChildProfile.empty;
    return ChildProfile(
      name: data['name'] as String? ?? '',
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      photoUrl: data['photoUrl'] as String?,
      // Safe for existing documents that predate this field — Firestore
      // simply returns null for a key that was never written.
      coverPhotoUrl: data['coverPhotoUrl'] as String?,
    );
  }

  /// e.g. "1 year 2 months", "3 months", "5 days"
  String get formattedAge {
    if (birthday == null) return '';
    final now = DateTime.now();
    var months = (now.year - birthday!.year) * 12 +
        (now.month - birthday!.month);
    if (now.day < birthday!.day) months -= 1;
    if (months < 0) months = 0;

    if (months < 1) {
      final days = now.difference(birthday!).inDays;
      return days <= 1 ? '$days day' : '$days days';
    }
    final years = months ~/ 12;
    final remMonths = months % 12;
    if (years == 0) {
      return remMonths == 1 ? '1 month' : '$remMonths months';
    }
    final yearLabel = years == 1 ? '1 year' : '$years years';
    if (remMonths == 0) return yearLabel;
    final monthLabel = remMonths == 1 ? '1 month' : '$remMonths months';
    return '$yearLabel $monthLabel';
  }
}

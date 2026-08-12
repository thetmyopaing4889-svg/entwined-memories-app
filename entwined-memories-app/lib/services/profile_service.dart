import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child_profile.dart';

/// Shared, single child profile stored in Firestore so every family
/// member sees the same name/birthday/photo instantly.
class ProfileService {
  static final _doc =
      FirebaseFirestore.instance.collection('child_profile').doc('info');
  static final _legacyDoc =
      FirebaseFirestore.instance.collection('app_data').doc('child_profile');

  /// Live stream of the child profile (used to drive the Home header).
  static Stream<ChildProfile> profileStream() {
    return _doc.snapshots().asyncMap((snap) async {
      if (snap.exists) return ChildProfile.fromMap(snap.data());

      // If an older APK wrote app_data/child_profile, migrate it on the
      // first realtime read so the existing Home timeline stays intact.
      final legacySnap = await _legacyDoc.get();
      if (!legacySnap.exists) return ChildProfile.empty;
      final profile = ChildProfile.fromMap(legacySnap.data());
      await _doc.set(profile.toMap());
      return profile;
    });
  }

  static Future<ChildProfile> loadProfile() async {
    final snap = await _doc.get();
    if (snap.exists) return ChildProfile.fromMap(snap.data());

    // Preserve profiles created by older APKs while moving the source of
    // truth to child_profile/info.
    final legacySnap = await _legacyDoc.get();
    if (!legacySnap.exists) return ChildProfile.empty;
    final profile = ChildProfile.fromMap(legacySnap.data());
    await _doc.set(profile.toMap());
    return profile;
  }

  static Future<void> saveProfile(ChildProfile profile) async {
    await _doc.set(profile.toMap());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child_profile.dart';

/// Shared, single child profile stored in Firestore so every family
/// member sees the same name/birthday/photo instantly.
class ProfileService {
  static final _doc =
      FirebaseFirestore.instance.collection('app_data').doc('child_profile');

  /// Live stream of the child profile (used to drive the Home header).
  static Stream<ChildProfile> profileStream() {
    return _doc.snapshots().map((snap) => ChildProfile.fromMap(snap.data()));
  }

  static Future<ChildProfile> loadProfile() async {
    final snap = await _doc.get();
    return ChildProfile.fromMap(snap.data());
  }

  static Future<void> saveProfile(ChildProfile profile) async {
    await _doc.set(profile.toMap());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Keeps onboarding completion tied to the shared Firestore profile instead
/// of one device's local storage. The profile itself is written by
/// ProfileService under child_profile/info.
class OnboardingService {
  static final _profileDoc =
      FirebaseFirestore.instance.collection('child_profile').doc('info');

  static Future<bool> isComplete() async {
    final snapshot = await _profileDoc.get();
    return snapshot.exists && (snapshot.data()?['name'] as String? ?? '').isNotEmpty;
  }

  static Future<void> markComplete() {
    // ProfileService.saveProfile is the authoritative write. This method is
    // retained for the existing onboarding flow and needs no local flag.
    return Future.value();
  }
}

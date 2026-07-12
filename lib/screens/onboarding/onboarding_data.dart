import 'dart:io';

/// Carries the story being written across the onboarding screens
/// (Create Child → Parents → Creating Home) before it is saved to
/// Firestore/Cloudinary all at once on the "Creating Home" step.
/// Plain in-memory holder — not persisted itself.
class OnboardingData {
  String childName = '';
  DateTime? birthday;
  File? profilePhoto;
  File? coverPhoto;
  String dadName = '';
  String momName = '';
}

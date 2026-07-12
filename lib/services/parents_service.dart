import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parents_profile.dart';

/// Shared parents record, stored the same way as ProfileService's child
/// profile doc — one document for the whole family space (Version 1 is
/// single-family only, per PROJECT_ARCHITECTURE.md).
class ParentsService {
  static final _doc =
      FirebaseFirestore.instance.collection('app_data').doc('parents');

  static Future<ParentsProfile> loadParents() async {
    final snap = await _doc.get();
    return ParentsProfile.fromMap(snap.data());
  }

  static Future<void> saveParents(ParentsProfile parents) async {
    await _doc.set(parents.toMap());
  }
}

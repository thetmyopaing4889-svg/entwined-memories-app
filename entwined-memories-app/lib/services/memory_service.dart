import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';

class MemoryService {
  static final _col = FirebaseFirestore.instance.collection('memories');
  static const _creatorNameKey = 'entwined_creator_name';

  // ── Real-time stream ──────────────────────────────────────────────────────

  /// Live stream of all memories, newest first.
  /// HomeScreen uses StreamBuilder on this — no manual refresh needed.
  static Stream<List<Memory>> memoriesStream() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Memory.fromFirestore).toList());
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  /// Save a new memory to Firestore (uses memory.id as document ID)
  static Future<void> addMemory(Memory memory) async {
    await _col.doc(memory.id).set(memory.toMap());
  }

  /// Update an existing memory in Firestore
  static Future<void> updateMemory(Memory updated) async {
    await _col.doc(updated.id).update(updated.toMap());
  }

  /// Delete a memory from Firestore by id
  static Future<void> deleteMemory(String id) async {
    await _col.doc(id).delete();
  }

  // ── Creator name (local preference) ──────────────────────────────────────

  /// Load the saved creator name (returns empty string if not set)
  static Future<String> loadCreatorName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_creatorNameKey) ?? '';
  }

  /// Persist creator name so it survives app restarts
  static Future<void> saveCreatorName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_creatorNameKey, name);
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory.dart';
import 'family_memory_journal_service.dart';
import 'original_vault_service.dart';

class FamilySettingsData {
  final String creatorName;
  final String playbackPreference;

  const FamilySettingsData({
    required this.creatorName,
    required this.playbackPreference,
  });
}

class MemoryService {
  static final _col = FirebaseFirestore.instance.collection('memories');
  static final _settingsDoc =
      FirebaseFirestore.instance.collection('app_data').doc('settings');

  // Retained only to migrate existing installations that predate Firestore
  // settings. Firestore is the source of truth after the first successful load.
  static const _creatorNameKey = 'entwined_creator_name';
  static const _playbackPreferenceKey = 'entwined_playback_preference';
  static const _workerBaseUrl =
      'https://entwined-memories.thetmyopaing4889.workers.dev';

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

  /// Writes a local journal intent before Firestore. If the online save later
  /// fails, the family still has an on-device record of what was attempted.
  /// A confirmed event is appended after a successful remote write; a failure
  /// to append that second event never rolls back a valid Firestore memory.
  static Future<void> addMemory(
    Memory memory, {
    Iterable<OriginalVaultArchive> vaultArchives = const [],
  }) async {
    final archives = List<OriginalVaultArchive>.unmodifiable(vaultArchives);
    await FamilyMemoryJournalService.appendMemoryEvent(
      eventType: 'memory_create_intent',
      memory: memory,
      vaultArchives: archives,
    );
    await _col.doc(memory.id).set(memory.toMap());
    try {
      await FamilyMemoryJournalService.appendMemoryEvent(
        eventType: 'memory_created',
        memory: memory,
        vaultArchives: archives,
      );
    } catch (_) {
      // The local intent event already exists. Do not turn a completed online
      // save into a user-visible failure because a second local event failed.
    }
  }

  /// Updates an existing memory and keeps an append-only local audit trail.
  static Future<void> updateMemory(
    Memory updated, {
    Iterable<OriginalVaultArchive> vaultArchives = const [],
  }) async {
    final archives = List<OriginalVaultArchive>.unmodifiable(vaultArchives);
    await FamilyMemoryJournalService.appendMemoryEvent(
      eventType: 'memory_update_intent',
      memory: updated,
      vaultArchives: archives,
    );
    await _col.doc(updated.id).update(updated.toMap());
    try {
      await FamilyMemoryJournalService.appendMemoryEvent(
        eventType: 'memory_updated',
        memory: updated,
        vaultArchives: archives,
      );
    } catch (_) {
      // Preserve the valid Firestore update; the intent event remains local.
    }
  }

  /// Update only the asynchronous YouTube processing state.
  ///
  /// Keeping this as a field update avoids overwriting a memory's note or
  /// media metadata when a background status poll completes.
  static Future<void> updateProcessingStatus(
      String memoryId, String processingStatus) async {
    await _col.doc(memoryId).update({
      'processingStatus': processingStatus,
    });
  }

  /// Deletes external media before removing the Firestore record. A cleanup
  /// failure deliberately leaves the memory document intact, so the user can
  /// retry rather than silently leaving an untracked photo or video behind.
  static Future<void> deleteMemory(Memory memory) async {
    // Existing installations may contain old records from before Journal setup.
    // Once a parent has selected the archive folder, never delete a Memory
    // without first recording the request locally.
    final journalConfigured =
        await FamilyMemoryJournalService.isArchiveFolderSelected();
    if (journalConfigured) {
      await FamilyMemoryJournalService.appendDeletionRequested(memory);
    }

    for (final photo in memory.allPhotos) {
      await cleanupImageAssets(
        imagePublicId: photo.imagePublicId,
        imageUrl: photo.imageUrl,
        displayMediaKey: photo.displayMediaKey,
      );
    }

    if (memory.hasVideo) {
      await _requestMediaCleanup('delete-video', {
        'videoId': memory.videoId,
      });
    }

    await _col.doc(memory.id).delete();

    if (journalConfigured) {
      try {
        await FamilyMemoryJournalService.appendDeleted(memory);
      } catch (_) {
        // The deletion request event remains. Never re-create deleted cloud
        // media merely because a confirmation event could not be appended.
      }
    }
  }

  /// Removes newly-uploaded photo copies when the Firestore write that should
  /// reference them fails. The Worker treats repeat deletes as safe retries.
  static Future<void> cleanupImageAssets({
    String? imagePublicId,
    String? imageUrl,
    String? displayMediaKey,
  }) {
    return _requestMediaCleanup('delete-image', {
      'imagePublicId': imagePublicId,
      'imageUrl': imageUrl,
      'displayMediaKey': displayMediaKey,
    });
  }

  /// Cleans up every newly-uploaded photo copy after a failed all-or-nothing
  /// gallery save. Cleanup is sequential to avoid a burst of concurrent
  /// authenticated Worker requests on a parent's mobile connection.
  static Future<void> cleanupImageAssetsBatch(
    Iterable<MemoryPhoto> photos,
  ) async {
    for (final photo in photos) {
      await cleanupImageAssets(
        imagePublicId: photo.imagePublicId,
        imageUrl: photo.imageUrl,
        displayMediaKey: photo.displayMediaKey,
      );
    }
  }

  static Future<void> _requestMediaCleanup(
    String route,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Media ဖျက်ရန် shared family account နဲ့ login ဝင်ရမယ်');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Media ဖျက်ရန် login token မရသေးဘူး');
    }

    final response = await http
        .post(
          Uri.parse('$_workerBaseUrl/$route'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Media cleanup မအောင်မြင်ဘူး';
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['error_description'] ?? data['error'];
      if (detail is String && detail.isNotEmpty) message = detail;
    } catch (_) {
      // Preserve a user-safe generic error when a proxy returns non-JSON.
    }
    throw StateError('HTTP ${response.statusCode}: $message');
  }

  // ── Family settings (Firestore source of truth) ───────────────────────────

  static Future<FamilySettingsData> loadFamilySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = FamilySettingsData(
      creatorName: prefs.getString(_creatorNameKey) ?? '',
      playbackPreference:
          _normalizePlayback(prefs.getString(_playbackPreferenceKey)),
    );

    try {
      final snapshot = await _settingsDoc.get();
      final data = snapshot.data();
      if (data != null) {
        return FamilySettingsData(
          creatorName: (data['creatorName'] as String? ?? '').trim(),
          playbackPreference:
              _normalizePlayback(data['playbackPreference'] as String?),
        );
      }

      // One-time migration for an existing installed app. This lets the shared
      // family name and slideshow choice survive an uninstall/reinstall.
      await _settingsDoc.set({
        'creatorName': legacy.creatorName,
        'playbackPreference': legacy.playbackPreference,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return legacy;
    } catch (_) {
      // Offline first-run support: existing local values remain a temporary
      // fallback until Firestore becomes reachable and migration can complete.
      return legacy;
    }
  }

  static Future<void> saveFamilySettings({
    String? creatorName,
    String? playbackPreference,
  }) async {
    final update = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (creatorName != null) update['creatorName'] = creatorName.trim();
    if (playbackPreference != null) {
      update['playbackPreference'] = _normalizePlayback(playbackPreference);
    }
    await _settingsDoc.set(update, SetOptions(merge: true));
  }

  static String _normalizePlayback(String? value) =>
      value == 'manual' ? 'manual' : 'auto';

  /// Compatibility helper used by AddMemoryScreen. The value now persists in
  /// app_data/settings instead of SharedPreferences.
  static Future<String> loadCreatorName() async {
    return (await loadFamilySettings()).creatorName;
  }

  static Future<void> saveCreatorName(String name) async {
    await saveFamilySettings(creatorName: name);
  }

  /// `auto` advances the full-screen story every four seconds; `manual`
  /// leaves page changes under the parent's control.
  static Future<String> loadPlaybackPreference() async {
    return (await loadFamilySettings()).playbackPreference;
  }

  static Future<void> savePlaybackPreference(String preference) async {
    await saveFamilySettings(playbackPreference: preference);
  }
}

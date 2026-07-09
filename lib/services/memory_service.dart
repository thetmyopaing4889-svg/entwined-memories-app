import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';

class MemoryService {
  static const String _storageKey = 'entwined_memories';
  static const String _creatorNameKey = 'entwined_creator_name';

  /// Load all memories from local storage, sorted newest first
  static Future<List<Memory>> loadMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = Memory.listFromJson(jsonStr);
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Save a new memory
  static Future<void> addMemory(Memory memory) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadMemories();
    existing.insert(0, memory);
    await prefs.setString(_storageKey, Memory.listToJson(existing));
  }

  /// Update an existing memory by id
  static Future<void> updateMemory(Memory updated) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadMemories();
    final index = list.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      list[index] = updated;
      list.sort((a, b) => b.date.compareTo(a.date));
      await prefs.setString(_storageKey, Memory.listToJson(list));
    }
  }

  /// Delete a memory by id
  static Future<void> deleteMemory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadMemories();
    list.removeWhere((m) => m.id == id);
    await prefs.setString(_storageKey, Memory.listToJson(list));
  }

  /// Load the saved creator name (returns empty string if not set)
  static Future<String> loadCreatorName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_creatorNameKey) ?? '';
  }

  /// Save creator name so it persists across sessions
  static Future<void> saveCreatorName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_creatorNameKey, name);
  }

  /// Clear all memories (for testing)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

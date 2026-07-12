import '../models/memory.dart';

/// Simple emotional summary counts for the Home hero section.
/// Intentionally minimal — this is not a dashboard, just three warm counts.
class MemoryStats {
  final int totalMemories;
  final int photoCount;
  final int videoCount;

  const MemoryStats({
    required this.totalMemories,
    required this.photoCount,
    required this.videoCount,
  });

  static const empty =
      MemoryStats(totalMemories: 0, photoCount: 0, videoCount: 0);

  factory MemoryStats.fromMemories(List<Memory> memories) {
    return MemoryStats(
      totalMemories: memories.length,
      photoCount: memories.where((m) => m.hasImage).length,
      videoCount: memories.where((m) => m.hasVideo).length,
    );
  }
}

import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../models/child_profile.dart';
import '../services/memory_service.dart';
import '../services/profile_service.dart';
import '../services/youtube_service.dart';
import '../utils/memory_stats.dart';
import '../widgets/home_hero.dart';
import '../widgets/memory_card.dart';
import 'add_memory_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _openAddMemory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
    );
  }

  Future<void> _openEditMemory(Memory memory) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddMemoryScreen(memory: memory)),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Memory ပြင်ပြီးပြီ ✨'),
        backgroundColor: Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deleteMemory(String id) async {
    await MemoryService.deleteMemory(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Memory ဖျက်ပြီးပြီ'),
        backgroundColor: Color(0xFFE8A0B4),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showDetail(Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemoryDetailSheet(memory: memory),
    );
  }

  void _showOptions(BuildContext ctx, Memory memory) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: Color(0xFFE8A0B4)),
              title: const Text('ပြင်မယ်'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditMemory(memory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('ဖျက်မယ်',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(memory.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Memory ဖျက်မလား?'),
        content: const Text('ဒီ memory ကို ပြန်မယူနိုင်တော့ဘူး'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('မဖျက်တော့ဘူး',
                style: TextStyle(color: Color(0xFFB0889A))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemory(id);
            },
            child: const Text('ဖျက်မယ်',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: StreamBuilder<List<Memory>>(
        stream: MemoryService.memoriesStream(),
        builder: (context, snapshot) {
          final memories = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final stats = MemoryStats.fromMemories(memories);

          return CustomScrollView(
            slivers: [
              // ── Home hero: cover photo, avatar, name, age, memory
              // summary, and today's letter. See widgets/home_hero.dart.
              SliverToBoxAdapter(
                child: StreamBuilder<ChildProfile>(
                  stream: ProfileService.profileStream(),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data ?? ChildProfile.empty;
                    return HomeHero(profile: profile, stats: stats);
                  },
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '📖 Her Story',
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3D2C33),
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(width: 10),
                          if (!isLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0E8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${memories.length}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8B3A52),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every memory, treasured forever.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE8A0B4)),
                  ),
                )
              else if (memories.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🌸',
                            style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        const Text(
                          'Memory ပထမဆုံး ထည့်ကြမယ်',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3D2C33)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ညာဘက်အောက် + ကို နှိပ်ပါ',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final memory = memories[index];
                      return MemoryCard(
                        memory: memory,
                        onTap: () => _showDetail(memory),
                        onLongPress: () => _showOptions(context, memory),
                      );
                    },
                    childCount: memories.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemory,
        backgroundColor: const Color(0xFFE8A0B4),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Memory ထည့်မယ်',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Memory Detail Bottom Sheet ────────────────────────────────────────────────
class _MemoryDetailSheet extends StatelessWidget {
  final Memory memory;
  const _MemoryDetailSheet({required this.memory});

  void _playInApp(BuildContext context) {
    if (!memory.isVideoReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Video အဆင်သင့်ဖြစ်အောင် processing လုပ်နေတယ်'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final videoId = memory.videoId!;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoId: videoId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // YouTube video thumbnail + watch button
            if (memory.hasVideo)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            YouTubeService.getThumbnailUrl(memory.videoId!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          GestureDetector(
                           onTap: memory.isVideoReady
                               ? () => _playInApp(context)
                               : null,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow,
                                  color: Colors.white, size: 36),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: memory.isVideoReady
                            ? () => _playInApp(context)
                            : null,
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('YouTube မှာ ကြည့်မယ်'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Photo
            if (!memory.hasVideo && memory.hasImage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    memory.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: const Color(0xFFFFE0E8),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFE8A0B4), strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(memory.formattedDate,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFB0889A),
                              fontWeight: FontWeight.w500)),
                      Text(memory.mood,
                          style: const TextStyle(fontSize: 28)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    memory.note,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF3D2C33),
                        height: 1.75,
                        letterSpacing: 0.1),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Added by ${memory.createdBy}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8B3A52),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

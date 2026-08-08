import 'dart:async';
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
import 'her_beginning_screen.dart';
import 'memory_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _processingPollInterval = Duration(seconds: 12);
  static const _processingPollTimeout = Duration(minutes: 5);
  final Set<String> _pollingVideoIds = <String>{};

  @override
  void dispose() {
    _pollingVideoIds.clear();
    super.dispose();
  }

  void _startProcessingPolling(List<Memory> memories) {
    for (final memory in memories) {
      if (memory.processingStatus == 'processing' &&
          memory.hasVideo &&
          _pollingVideoIds.add(memory.videoId!)) {
        unawaited(_pollVideoUntilComplete(memory));
      }
    }
  }

  Future<void> _pollVideoUntilComplete(Memory memory) async {
    final deadline = DateTime.now().add(_processingPollTimeout);
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final status =
              await YouTubeService.getVideoProcessingStatus(memory.videoId!);
          if (status == 'succeeded') {
            await MemoryService.updateProcessingStatus(memory.id, 'ready');
            return;
          }
          if (status == 'failed') {
            await MemoryService.updateProcessingStatus(memory.id, 'failed');
            return;
          }
        } catch (_) {
          // A temporary network/API error should not strand the memory in a
          // permanent state. The next interval will retry within the timeout.
        }

        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) return;
        await Future<void>.delayed(
          remaining < _processingPollInterval
              ? remaining
              : _processingPollInterval,
        );
      }
    } finally {
      _pollingVideoIds.remove(memory.videoId);
    }
  }

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
    Navigator.push(
      context: context,
      MaterialPageRoute(
        builder: (_) => MemoryDetailScreen(memory: memory),
      ),
    );
  }

  void _openBeginning(ChildProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HerBeginningScreen(profile: profile),
      ),
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
          _startProcessingPolling(memories);
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final stats = MemoryStats.fromMemories(memories);

          if (snapshot.hasError) {
            return _HomeErrorState(
              message: 'Memory timeline ဖွင့်မရသေးဘူး',
              detail: 'Internet connection နဲ့ Firestore ကို စစ်ပြီး ထပ်ကြိုးစားပါ။',
            );
          }

          return CustomScrollView(
            slivers: [
              // ── Home hero: cover photo, avatar, name, age, memory
              // summary, and today's letter. See widgets/home_hero.dart.
              SliverToBoxAdapter(
                child: StreamBuilder<ChildProfile>(
                  stream: ProfileService.profileStream(),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data ?? ChildProfile.empty;
                    return HomeHero(
                      profile: profile,
                      stats: stats,
                      onViewBeginning: () => _openBeginning(profile),
                    );
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

class _HomeErrorState extends StatelessWidget {
  final String message;
  final String detail;

  const _HomeErrorState({
    required this.message,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Color(0xFFE8A0B4),
              size: 54,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF3D2C33),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB0889A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

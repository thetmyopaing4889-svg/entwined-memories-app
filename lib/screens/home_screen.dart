import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memory.dart';
import '../models/child_profile.dart';
import '../services/memory_service.dart';
import '../services/profile_service.dart';
import '../services/youtube_service.dart';
import '../widgets/memory_card.dart';
import 'add_memory_screen.dart';

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
      body: StreamBuilder<List<Memory>>(
        stream: MemoryService.memoriesStream(),
        builder: (context, snapshot) {
          final memories = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                backgroundColor: const Color(0xFFFFF5F7),
                flexibleSpace: const FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _ChildProfileHeader(),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                      height: 1, color: const Color(0xFFFFE0E8)),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                    color: const Color(0xFFE8A0B4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                    color: const Color(0xFFE8A0B4),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Memories',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3D2C33)),
                      ),
                      const SizedBox(width: 8),
                      if (!isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
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

// ── Child Profile Header ──────────────────────────────────────────────────────
class _ChildProfileHeader extends StatelessWidget {
  const _ChildProfileHeader();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChildProfile>(
      stream: ProfileService.profileStream(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? ChildProfile.empty;
        final name = profile.name.isNotEmpty ? profile.name : 'Baby Name';
        final age = profile.formattedAge;

        return Container(
          color: const Color(0xFFFFF5F7),
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFE0E8),
                  image: (profile.photoUrl != null &&
                          profile.photoUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(profile.photoUrl!),
                          fit: BoxFit.cover)
                      : null,
                  border:
                      Border.all(color: const Color(0xFFE8A0B4), width: 2.5),
                ),
                child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                    ? const Icon(Icons.child_care,
                        size: 36, color: Color(0xFFE8A0B4))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3D2C33),
                          letterSpacing: -0.5),
                    ),
                    if (age.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          age,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8B3A52),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Memory Detail Bottom Sheet ────────────────────────────────────────────────
class _MemoryDetailSheet extends StatelessWidget {
  final Memory memory;
  const _MemoryDetailSheet({required this.memory});

  Future<void> _openYouTube(BuildContext context) async {
    final url = Uri.parse(YouTubeService.getWatchUrl(memory.videoId!));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('YouTube ဖွင့်မရဘူး'),
          backgroundColor: Color(0xFFE8A0B4),
        ));
      }
    }
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
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: Colors.white, size: 36),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openYouTube(context),
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

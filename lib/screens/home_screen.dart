import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../widgets/memory_card.dart';
import 'add_memory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // No local list — Firestore StreamBuilder handles real-time updates.

  Future<void> _openAddMemory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
    );
    // Firestore stream auto-refreshes the list.
  }

  Future<void> _openEditMemory(Memory memory) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddMemoryScreen(memory: memory)),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory updated ✨'),
          backgroundColor: Color(0xFFE8A0B4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMemory(String id) async {
    await MemoryService.deleteMemory(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory deleted.'),
          backgroundColor: Color(0xFFE8A0B4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              // ── Sticky App Bar with child profile ───────────────────────
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
                  child:
                      Container(height: 1, color: const Color(0xFFFFE0E8)),
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

              // ── Timeline label + count ───────────────────────────────────
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
                          color: Color(0xFF3D2C33),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${memories.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8B3A52),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Loading / Empty / List ───────────────────────────────────
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE8A0B4),
                    ),
                  ),
                )
              else if (memories.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💕',
                            style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        const Text(
                          'No memories yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3D2C33),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first memory',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF3D2C33).withOpacity(0.5),
                          ),
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
                        onTap: () => _showMemoryDetail(context, memory),
                        onLongPress: () =>
                            _showMemoryOptions(context, memory),
                      );
                    },
                    childCount: memories.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMemory,
        backgroundColor: const Color(0xFFE8A0B4),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showMemoryDetail(BuildContext context, Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemoryDetailSheet(memory: memory),
    );
  }

  void _showMemoryOptions(BuildContext context, Memory memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: Color(0xFFE8A0B4)),
              title: const Text('Edit Memory'),
              onTap: () {
                Navigator.pop(context);
                _openEditMemory(memory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              title: const Text('Delete Memory',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, memory.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Memory?'),
        content: const Text('This memory will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB0889A))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemory(id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Child Profile Header ──────────────────────────────────────────────────────
class _ChildProfileHeader extends StatelessWidget {
  const _ChildProfileHeader();

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: const Color(0xFFE8A0B4), width: 2.5),
            ),
            child: const Icon(Icons.child_care,
                size: 36, color: Color(0xFFE8A0B4)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Baby Name',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3D2C33),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '1 year 2 months',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8B3A52),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Memory Detail Bottom Sheet ────────────────────────────────────────────────
class _MemoryDetailSheet extends StatelessWidget {
  final Memory memory;
  const _MemoryDetailSheet({required this.memory});

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

            // Image
            if (memory.imageUrl != null)
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
                            color: Color(0xFFE8A0B4),
                            strokeWidth: 2,
                          ),
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
                      Text(
                        memory.formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB0889A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                      letterSpacing: 0.1,
                    ),
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
                        fontWeight: FontWeight.w600,
                      ),
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

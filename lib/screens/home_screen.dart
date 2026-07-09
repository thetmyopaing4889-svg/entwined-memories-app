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
  List<Memory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    final memories = await MemoryService.loadMemories();
    if (mounted) {
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddMemory() async {
    final result = await Navigator.push<Memory>(
      context,
      MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
    );
    if (result != null) {
      setState(() {
        _memories.insert(0, result);
      });
    }
  }

  Future<void> _deleteMemory(String id) async {
    await MemoryService.deleteMemory(id);
    setState(() => _memories.removeWhere((m) => m.id == id));
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
      body: CustomScrollView(
        slivers: [
          // Sticky App Bar with child profile
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: const Color(0xFFFFF5F7),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: const _ChildProfileHeader(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFFFE0E8)),
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

          // Timeline label + count
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_memories.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8A0B4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading state
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE8A0B4),
                  strokeWidth: 2.5,
                ),
              ),
            )

          // Empty state
          else if (_memories.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0E8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_stories_outlined,
                        size: 44,
                        color: Color(0xFFE8A0B4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No memories yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3D2C33),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap the button below to add\nyour first memory ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB0889A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )

          // Memory list
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final memory = _memories[index];
                  return MemoryCard(
                    memory: memory,
                    onTap: () => _showMemoryDetail(context, memory),
                    onLongPress: () => _showMemoryOptions(context, memory),
                  );
                },
                childCount: _memories.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      bottomNavigationBar: const _BottomNav(),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemory,
        backgroundColor: const Color(0xFFE8A0B4),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Memory',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
              leading: const Icon(Icons.edit_outlined, color: Color(0xFFE8A0B4)),
              title: const Text('Edit Memory'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Edit coming soon!'),
                    backgroundColor: Color(0xFFE8A0B4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Memory?'),
        content: const Text(
            'This memory will be permanently removed.'),
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
            child: const Icon(Icons.child_care, size: 36,
                color: Color(0xFFE8A0B4)),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🎂 1 year 2 months',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB0889A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(Icons.play_circle_outline),
              color: const Color(0xFFE8A0B4),
              iconSize: 28,
              onPressed: () {},
              tooltip: 'Play Memories',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0xFFE8A0B4),
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _NavItem(icon: Icons.home_filled, label: 'Home', selected: true),
          _NavItem(icon: Icons.child_care, label: 'Profile'),
          SizedBox(width: 56),
          _NavItem(icon: Icons.play_circle_outline, label: 'Playback'),
          _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFFE8A0B4) : const Color(0xFFB0889A);
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Memory Detail Sheet ───────────────────────────────────────────────────────
class _MemoryDetailSheet extends StatelessWidget {
  final Memory memory;
  const _MemoryDetailSheet({required this.memory});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.photo_camera_outlined,
                    size: 48, color: Color(0xFFE8A0B4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      fontSize: 16,
                      color: Color(0xFF3D2C33),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        color: Color(0xFFB0889A),
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

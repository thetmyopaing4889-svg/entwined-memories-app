import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../widgets/youtube_thumbnail.dart';
import 'add_memory_screen.dart';
import 'video_player_screen.dart';

class MemoryDetailScreen extends StatefulWidget {
  final Memory memory;

  const MemoryDetailScreen({super.key, required this.memory});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  bool _deleting = false;

  Future<void> _edit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMemoryScreen(memory: widget.memory),
      ),
    );
    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Memory ဖျက်မလား?'),
        content: const Text('ဒီ memory ကို ပြန်မယူနိုင်တော့ဘူး'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'မဖျက်တော့ဘူး',
              style: TextStyle(color: Color(0xFFB0889A)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ဖျက်မယ်'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await MemoryService.deleteMemory(widget.memory);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Memory ဖျက်မရသေးဘူး: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openVideo() {
    if (!widget.memory.isVideoReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video အဆင်သင့်ဖြစ်အောင် processing လုပ်နေတယ်'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoId: widget.memory.videoId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memory = widget.memory;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text('Memory Detail'),
        actions: [
          IconButton(
            onPressed: _deleting ? null : _edit,
            tooltip: 'Edit memory',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleting ? null : _delete,
            tooltip: 'Delete memory',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
      body: _deleting
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (memory.hasVideo) _VideoDetailMedia(memory: memory, onPlay: _openVideo),
                if (!memory.hasVideo && memory.hasImage)
                  _PhotoDetailMedia(url: memory.imageUrl!),
                if (!memory.hasVideo && !memory.hasImage)
                  const _NoMediaCard(),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              memory.formattedDate,
                              style: const TextStyle(
                                color: Color(0xFFB0889A),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(memory.mood, style: const TextStyle(fontSize: 30)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        memory.note,
                        style: const TextStyle(
                          color: Color(0xFF3D2C33),
                          fontSize: 17,
                          height: 1.75,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0E8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Added by ${memory.createdBy}',
                          style: const TextStyle(
                            color: Color(0xFF8B3A52),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Memory ပြင်မယ်'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B3A52),
                    side: const BorderSide(color: Color(0xFFFFC9D8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _VideoDetailMedia extends StatelessWidget {
  final Memory memory;
  final VoidCallback onPlay;

  const _VideoDetailMedia({required this.memory, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final ready = memory.isVideoReady;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          YouTubeThumbnailImage(
            videoId: memory.videoId!,
            width: double.infinity,
            height: 230,
          ),
          if (ready)
            Material(
              color: Colors.black.withOpacity(0.68),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPlay,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.68),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                memory.processingStatus == 'failed'
                    ? 'Video processing failed'
                    : 'Video processing...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoDetailMedia extends StatelessWidget {
  final String url;

  const _PhotoDetailMedia({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        url,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)),
            ),
          );
        },
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 300,
          child: _MediaErrorState(),
        ),
      ),
    );
  }
}

class _NoMediaCard extends StatelessWidget {
  const _NoMediaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6ED),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const _MediaErrorState(
        icon: Icons.auto_awesome_outlined,
        message: 'ဒီ memory မှာ photo/video မပါသေးပါ',
      ),
    );
  }
}

class _MediaErrorState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MediaErrorState({
    this.icon = Icons.broken_image_outlined,
    this.message = 'Media ဖွင့်မရသေးပါ',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFE8A0B4), size: 42),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF8B3A52),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
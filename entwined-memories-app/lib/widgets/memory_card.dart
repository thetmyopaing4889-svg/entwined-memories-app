import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../screens/video_player_screen.dart';
import 'full_screen_photo_viewer.dart';
import 'youtube_thumbnail.dart';

class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const MemoryCard({
    super.key,
    required this.memory,
    required this.onEdit,
    required this.onDelete,
    required this.onViewDetails,
  });

  void _openVideo(BuildContext context) {
    if (!memory.hasVideo || !memory.isVideoReady) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoId: memory.videoId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (memory.hasVideo)
            _VideoThumbnail(
              videoId: memory.videoId!,
              processingStatus: memory.processingStatus,
              onTap: () => _openVideo(context),
            ),
          if (!memory.hasVideo && memory.hasImage)
            _ImagePreview(url: memory.imageUrl!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        memory.formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB0889A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(memory.mood,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 4),
                    PopupMenuButton<_MemoryAction>(
                      tooltip: 'Memory options',
                      icon: const Icon(Icons.more_horiz,
                          color: Color(0xFF8B3A52)),
                      onSelected: (action) {
                        switch (action) {
                          case _MemoryAction.edit:
                            onEdit();
                            break;
                          case _MemoryAction.delete:
                            onDelete();
                            break;
                          case _MemoryAction.detail:
                            onViewDetails();
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _MemoryAction.edit,
                          child: _MenuItem(
                            icon: Icons.edit_outlined,
                            label: 'ပြင်မယ်',
                          ),
                        ),
                        PopupMenuItem(
                          value: _MemoryAction.delete,
                          child: _MenuItem(
                            icon: Icons.delete_outline,
                            label: 'ဖျက်မယ်',
                            isDestructive: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: _MemoryAction.detail,
                          child: _MenuItem(
                            icon: Icons.open_in_new_rounded,
                            label: 'အသေးစိတ်ကြည့်မယ်',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  memory.note,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3D2C33),
                    height: 1.75,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: Color(0xFFB05070)),
                      const SizedBox(width: 4),
                      Text(
                        'Added by ${memory.createdBy}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B3A52),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

enum _MemoryAction { edit, delete, detail }

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : const Color(0xFF3D2C33);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String videoId;
  final String? processingStatus;
  final VoidCallback onTap;

  const _VideoThumbnail({
    required this.videoId,
    required this.processingStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = processingStatus == null || processingStatus == 'ready';
    return Semantics(
      button: isReady,
      label: isReady ? 'Play video memory' : 'Video processing status',
      child: InkWell(
        onTap: isReady ? onTap : null,
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              YouTubeThumbnailImage(
                videoId: videoId,
                width: double.infinity,
                height: 200,
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(isReady ? 0.65 : 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReady ? Icons.play_arrow : Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('YouTube',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              if (!isReady)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      processingStatus == 'failed'
                          ? 'Video unavailable'
                          : 'Video processing...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String url;
  const _ImagePreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open memory photo full screen',
      child: InkWell(
        onTap: () => showFullScreenPhotoViewer(
          context,
          imageProvider: NetworkImage(url),
          semanticsLabel: 'Memory photo full screen preview',
        ),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFFFFE0E8),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFE8A0B4), strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFFFE0E8),
              child: const Icon(Icons.broken_image_outlined,
                  color: Color(0xFFE8A0B4), size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

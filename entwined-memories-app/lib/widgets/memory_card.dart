import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../models/memory.dart';
import '../services/display_media_service.dart';
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
    final colors = Theme.of(context).colorScheme;
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
            _ImagePreview(memory: memory),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(memory.mood, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 4),
                    PopupMenuButton<_MemoryAction>(
                      tooltip: 'Memory options',
                      icon: Icon(Icons.more_horiz, color: colors.primary),
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
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.onSurface,
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
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: colors.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Added by ${memory.createdBy}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onPrimaryContainer,
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
    final colors = Theme.of(context).colorScheme;
    final color = isDestructive ? colors.error : colors.onSurface;
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
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              YouTubeThumbnailImage(videoId: videoId),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
  final Memory memory;
  const _ImagePreview({required this.memory});

  Future<void> _openPhoto(BuildContext context) async {
    final thumbnailUrl = memory.feedThumbnailUrl!;
    try {
      if (memory.hasPrivateDisplay) {
        final request = await DisplayMediaService.authorizedDisplayRequest(
          memory.displayMediaKey!,
        );
        if (!context.mounted) return;
        await showFullScreenPhotoViewer(
          context,
          imageProvider: CachedNetworkImageProvider(
            request.url,
            headers: request.headers,
          ),
          semanticsLabel: 'Memory photo full screen preview',
        );
        return;
      }

      await showFullScreenPhotoViewer(
        context,
        imageProvider: CachedNetworkImageProvider(thumbnailUrl),
        semanticsLabel: 'Memory photo full screen preview',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full photo ဖွင့်မရသေးဘူး။ ပြန်စမ်းပါ။')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final thumbnailUrl = memory.feedThumbnailUrl!;
    return Semantics(
      button: true,
      label: 'Open memory photo full screen',
      child: InkWell(
        onTap: () => _openPhoto(context),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: 960,
            placeholder: (_, __) => Container(
              color: colors.surfaceContainerHighest,
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: colors.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.primary,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

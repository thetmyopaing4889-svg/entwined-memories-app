import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/youtube_service.dart';

class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MemoryCard({
    super.key,
    required this.memory,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Media preview ─────────────────────────────────────────────
            if (memory.hasVideo) _VideoThumbnail(videoId: memory.videoId!),
            if (!memory.hasVideo && memory.hasImage) _ImagePreview(url: memory.imageUrl!),

            // ── Content ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
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
                          style: const TextStyle(fontSize: 22)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
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
      ),
    );
  }
}

// ── YouTube video thumbnail with play button overlay ──────────────────────────
class _VideoThumbnail extends StatelessWidget {
  final String videoId;
  const _VideoThumbnail({required this.videoId});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            YouTubeService.getThumbnailUrl(videoId),
            width: double.infinity,
            height: 200,
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
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: Colors.black87,
              child: const Center(
                child: Icon(Icons.videocam_off,
                    color: Colors.white54, size: 48),
              ),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow,
                color: Colors.white, size: 32),
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
        ],
      ),
    );
  }
}

// ── Photo preview ─────────────────────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final String url;
  const _ImagePreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Image.network(
        url,
        width: double.infinity,
        height: 200,
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
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: const Color(0xFFFFE0E8),
          child: const Icon(Icons.broken_image_outlined,
              color: Color(0xFFE8A0B4), size: 48),
        ),
      ),
    );
  }
}

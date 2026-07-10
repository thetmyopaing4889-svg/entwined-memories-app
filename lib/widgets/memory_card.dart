import 'package:flutter/material.dart';
import '../models/memory.dart';

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
            // ── Image (only if present) ───────────────────────────────────
            if (memory.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  memory.imageUrl!,
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
                          color: Color(0xFFE8A0B4),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: const Color(0xFFFFE0E8),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFFE8A0B4),
                      size: 48,
                    ),
                  ),
                ),
              ),

            // ── Content ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + Mood row
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
                      Text(memory.mood, style: const TextStyle(fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Note text
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

                  // "Added by" badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: Color(0xFFB05070),
                        ),
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

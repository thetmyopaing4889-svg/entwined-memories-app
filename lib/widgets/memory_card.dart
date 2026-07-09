import 'dart:io';
import 'package:flutter/material.dart';
import '../models/memory.dart';

class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MemoryCard({
    super.key,
    required this.memory,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8A0B4).withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — only show if path exists and file is valid
            if (memory.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.file(
                  File(memory.imageUrl!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + Mood row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Color(0xFFB0889A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            memory.formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB0889A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        memory.mood,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Note text — improved line height for Myanmar text
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

                  // "Added by" badge — darker, more readable
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
                            color: Color(0xFF8B3A52), // darker, more readable
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

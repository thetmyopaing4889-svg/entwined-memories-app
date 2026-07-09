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

  Color get _creatorColor {
    return memory.createdBy == 'Mom'
        ? const Color(0xFFFFB6C1) // soft pink for Mom
        : const Color(0xFFB4C9E8); // soft blue for Dad
  }

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
            // Image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 200,
                width: double.infinity,
                color: const Color(0xFFFFF0F3),
                child: const Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 48,
                    color: Color(0xFFE8A0B4),
                  ),
                ),
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
                            memory.date,
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

                  // Note text
                  Text(
                    memory.note,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF3D2C33),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Created by badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _creatorColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: _creatorColor.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Added by ${memory.createdBy}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _creatorColor.withOpacity(0.9),
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

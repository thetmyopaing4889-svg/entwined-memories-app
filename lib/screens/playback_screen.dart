import 'package:flutter/material.dart';

/// Placeholder for the FB-style "Memory Playback" feature:
/// pick a time range → replay all photos/videos in that range as a
/// story/slideshow. Full implementation coming later.
class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(title: const Text('Playback')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎬', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              const Text(
                'Memory Playback',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D2C33)),
              ),
              const SizedBox(height: 10),
              Text(
                'Time range ရွေးပြီး memory တွေအားလုံးကို\n'
                'slideshow ပုံစံနဲ့ ပြန်ကြည့်နိုင်မယ့် feature —\n'
                'မကြာခင် လာပါမယ် 💕',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[500], height: 1.6),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Playback (Coming soon)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB0889A),
                  side: const BorderSide(color: Color(0xFFFFD6E4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'playback_screen.dart';
import 'settings_screen.dart';

/// Root shell with the bottom navigation bar: Home / Profile / Playback / Settings.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    ProfileScreen(),
    PlaybackScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE0E8),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Color(0xFFB0889A)),
            selectedIcon: Icon(Icons.home, color: Color(0xFFE8A0B4)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.child_care_outlined, color: Color(0xFFB0889A)),
            selectedIcon: Icon(Icons.child_care, color: Color(0xFFE8A0B4)),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline, color: Color(0xFFB0889A)),
            selectedIcon: Icon(Icons.play_circle, color: Color(0xFFE8A0B4)),
            label: 'Playback',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Color(0xFFB0889A)),
            selectedIcon: Icon(Icons.settings, color: Color(0xFFE8A0B4)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

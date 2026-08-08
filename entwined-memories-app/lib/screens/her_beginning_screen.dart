import 'package:flutter/material.dart';
import '../models/child_profile.dart';

class HerBeginningScreen extends StatelessWidget {
  final ChildProfile profile;

  const HerBeginningScreen({super.key, required this.profile});

  String _formatBirthday(DateTime? date) {
    if (date == null) return 'Birthday not added yet';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile.name.trim().isEmpty ? 'Your baby' : profile.name.trim();
    final age = profile.birthday == null
        ? 'Every chapter starts with love.'
        : _formatAge(profile.birthday!);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(title: const Text('Her Beginning')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          Container(
            height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDCE7), Color(0xFFFFF0F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(profile.photoUrl!),
                      fit: BoxFit.cover,
                      colorFilter: const ColorFilter.mode(
                        Colors.black26,
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.child_care_rounded,
                      size: 84,
                      color: Color(0xFFE8A0B4),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            'The day $name began',
            style: const TextStyle(
              color: Color(0xFF3D2C33),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'A small beginning. A lifetime of memories.',
            style: TextStyle(
              color: Color(0xFF8B3A52),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.cake_outlined,
            label: 'Birthday',
            value: _formatBirthday(profile.birthday),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.favorite_outline,
            label: 'Growing beautifully',
            value: age,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              'This is a quiet place for the first pages of her story — '
              'the little details, the first smiles, and all the love that '
              'surrounded her from the very beginning.',
              style: TextStyle(
                color: Color(0xFF3D2C33),
                fontSize: 16,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(DateTime birthday) {
    final now = DateTime.now();
    var months = (now.year - birthday.year) * 12 + now.month - birthday.month;
    if (now.day < birthday.day) months -= 1;
    if (months <= 0) {
      final days = now.difference(birthday).inDays.clamp(0, 99999).toInt();
      return days == 1 ? '1 day of wonder' : '$days days of wonder';
    }
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) {
      return remainingMonths == 1
          ? '1 month of wonder'
          : '$remainingMonths months of wonder';
    }
    if (remainingMonths == 0) {
      return years == 1 ? '1 year of wonder' : '$years years of wonder';
    }
    final yearLabel = years == 1 ? '1 year' : '$years years';
    final monthLabel =
        remainingMonths == 1 ? '1 month' : '$remainingMonths months';
    return '$yearLabel $monthLabel of wonder';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(
              color: Color(0xFFFFE6ED),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFB05070), size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFB0889A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF3D2C33),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
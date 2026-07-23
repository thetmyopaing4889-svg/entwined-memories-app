import 'package:flutter/material.dart';

/// Section 2 of the Home Screen — a permanently pinned card summarizing
/// the day her story began. NOT part of the timeline; the full detail
/// page is a future sprint, so this only ever shows a short summary or
/// a graceful empty state.
///
/// All fields are optional and currently unused by any screen — there is
/// no existing Firestore field or input flow for birth info yet, so this
/// card intentionally always renders its empty state for V1. It already
/// accepts real values so a future sprint can wire them in without
/// touching HomeScreen again.
class HerBeginningCard extends StatelessWidget {
  final String? hospital;
  final String? location;
  final String? birthWeight;

  const HerBeginningCard({
    super.key,
    this.hospital,
    this.location,
    this.birthWeight,
  });

  bool get _hasData =>
      (hospital != null && hospital!.trim().isNotEmpty) ||
      (location != null && location!.trim().isNotEmpty) ||
      (birthWeight != null && birthWeight!.trim().isNotEmpty);

  void _viewStory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('သူငယ်ချင်း ဇာတ်လမ်းအပြည့်အစုံ မကြာမီ ရောက်လာပါမယ် 💕'),
      backgroundColor: Color(0xFFE8A0B4),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F4), Color(0xFFFFE6ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '❤️ Her Beginning',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B3A52),
            ),
          ),
          const SizedBox(height: 12),
          if (_hasData) ..._buildSummary() else _buildEmptyState(),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _viewStory(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Story',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB0889A),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: Color(0xFFB0889A)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSummary() {
    final rows = <Widget>[];
    if (hospital != null && hospital!.trim().isNotEmpty) {
      rows.add(_InfoRow(label: 'Born at', value: hospital!.trim()));
    }
    if (location != null && location!.trim().isNotEmpty) {
      rows.add(_InfoRow(label: 'Location', value: location!.trim()));
    }
    if (birthWeight != null && birthWeight!.trim().isNotEmpty) {
      rows.add(_InfoRow(label: 'Birth Weight', value: birthWeight!.trim()));
    }
    return rows;
  }

  Widget _buildEmptyState() {
    return const Text(
      'The story of her very first day is\nwaiting to be written.',
      style: TextStyle(
        fontSize: 13.5,
        fontStyle: FontStyle.italic,
        color: Color(0xFFB0889A),
        height: 1.6,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Color(0xFF3D2C33)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF8B3A52)),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

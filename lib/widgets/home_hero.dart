import 'package:flutter/material.dart';
import '../models/child_profile.dart';
import '../utils/age_calculator.dart';
import '../utils/memory_stats.dart';
import 'her_beginning_card.dart';

/// The Home screen hero section — cover photo, child profile photo, name,
/// emotional age copy, a minimal memory summary, and a short letter from
/// the parents.
///
/// Purely presentational: it does not touch Firestore, Cloudinary,
/// YouTube, or navigation — all data is passed in by [HomeScreen].
class HomeHero extends StatelessWidget {
  final ChildProfile profile;
  final MemoryStats stats;

  const HomeHero({
    super.key,
    required this.profile,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        profile.name.trim().isNotEmpty ? profile.name.trim() : 'Baby Name';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoverAndAvatar(profile: profile),
        const SizedBox(height: 44), // clears the overlapping avatar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3D2C33),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              _AgeBlock(birthday: profile.birthday),
              const SizedBox(height: 24),
              const HerBeginningCard(),
              const SizedBox(height: 22),
              _MemorySummary(stats: stats),
              const SizedBox(height: 24),
              const _TodaysLetter(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Cover photo + overlapping avatar ───────────────────────────────────────
class _CoverAndAvatar extends StatelessWidget {
  final ChildProfile profile;
  const _CoverAndAvatar({required this.profile});

  static const _coverHeight = 200.0;
  static const _avatarSize = 96.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _coverHeight + _avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: SizedBox(
              width: double.infinity,
              height: _coverHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (profile.coverPhotoUrl != null &&
                      profile.coverPhotoUrl!.isNotEmpty)
                    Image.network(
                      profile.coverPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const _CoverPlaceholder();
                      },
                    )
                  else
                    const _CoverPlaceholder(),
                  // Warm pastel gradient overlay so the avatar/name area
                  // stays readable whether or not a real cover photo exists.
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00FFF5F7),
                          Color(0xCCFFF5F7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: _coverHeight - _avatarSize / 2,
            child: _ProfileAvatar(profile: profile, size: _avatarSize),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE0E8), Color(0xFFFFC9D9), Color(0xFFFFB6C1)],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ChildProfile profile;
  final double size;
  const _ProfileAvatar({required this.profile, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = profile.photoUrl != null && profile.photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFE0E8),
        border: Border.all(color: Colors.white, width: 4),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(profile.photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: hasPhoto
          ? null
          : Icon(Icons.child_care,
              size: size * 0.5, color: const Color(0xFFE8A0B4)),
    );
  }
}

// ── Emotional age block ─────────────────────────────────────────────────────
class _AgeBlock extends StatelessWidget {
  final DateTime? birthday;
  const _AgeBlock({required this.birthday});

  @override
  Widget build(BuildContext context) {
    final birthdayValue = birthday;
    if (birthdayValue == null) {
      return const Text(
        'Her story is waiting to begin.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: Color(0xFFB0889A),
        ),
      );
    }

    final age = calculateAgeBreakdown(birthdayValue);
    return Column(
      children: [
        const Text(
          'Today she is',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFFB0889A),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${age.years} Years\n${age.months} Months\n${age.days} Days old',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B3A52),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Minimal memory summary (not a dashboard) ───────────────────────────────
class _MemorySummary extends StatelessWidget {
  final MemoryStats stats;
  const _MemorySummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SummaryItem(
            emoji: '❤️', label: 'Memories', count: stats.totalMemories),
        const _SummaryDivider(),
        _SummaryItem(emoji: '📸', label: 'Photos', count: stats.photoCount),
        const _SummaryDivider(),
        _SummaryItem(emoji: '🎥', label: 'Videos', count: stats.videoCount),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: const Color(0xFFFFE0E8),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  const _SummaryItem({
    required this.emoji,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$emoji $count',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D2C33))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

// ── Today's Letter ──────────────────────────────────────────────────────────
class _TodaysLetter extends StatelessWidget {
  const _TodaysLetter();

  static const _defaultLetter =
      'သမီးလေးရေ...\nဒီအပြုံးလေးက ပါးပါးနဲ့ မာမား\nလောကဓံကို ရင်ဆိုင်နိုင်တဲ့\nအကြီးမားဆုံး အားအင်ပါ။ ❤️';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💌 Today\'s Letter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B3A52),
            ),
          ),
          SizedBox(height: 10),
          Text(
            _defaultLetter,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF3D2C33),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

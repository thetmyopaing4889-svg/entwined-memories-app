import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';

import '../models/memory.dart';
import '../services/memory_service.dart';
import '../widgets/private_display_image.dart';
import '../widgets/youtube_thumbnail.dart';
import 'memory_detail_screen.dart';
import 'video_player_screen.dart';
import '../services/app_settings.dart';

class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({super.key});

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  DateTimeRange? _range;
  bool _autoPlay = true;

  @override
  void initState() {
    super.initState();
    _loadPlaybackPreference();
  }

  Future<void> _loadPlaybackPreference() async {
    final preference = await MemoryService.loadPlaybackPreference();
    if (mounted) setState(() => _autoPlay = preference != 'manual');
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: const Color(0xFFE8A0B4)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  void _clearRange() => setState(() => _range = null);

  List<Memory> _filter(List<Memory> memories) {
    final range = _range;
    if (range == null) return memories;
    return memories.where((memory) {
      final date =
          DateTime(memory.date.year, memory.date.month, memory.date.day);
      final start =
          DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  String _rangeLabel() {
    final range = _range;
    if (range == null) return 'All memories';
    return '${_shortDate(range.start)} – ${_shortDate(range.end)}';
  }

  String _shortDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _openStory(List<Memory> memories, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryStoryScreen(
          memories: memories,
          initialIndex: index,
          autoPlay: _autoPlay,
        ),
      ),
    );
  }

  void _openDetail(Memory memory) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemoryDetailScreen(memory: memory)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(strings.playback)),
      body: StreamBuilder<List<Memory>>(
        stream: MemoryService.memoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _PlaybackError(message: 'Memories ဖွင့်မရသေးဘူး');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)),
            );
          }

          final memories = _filter(snapshot.data ?? []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _PlaybackIntro(
                rangeLabel: _rangeLabel(),
                hasRange: _range != null,
                onPickRange: _pickRange,
                onClearRange: _clearRange,
              ),
              const SizedBox(height: 18),
              if (memories.isEmpty)
                const _PlaybackEmpty()
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openStory(memories, 0),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start memory story'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A0B4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${memories.length} ${memories.length == 1 ? 'memory' : 'memories'} in this story',
                  style: const TextStyle(
                    color: Color(0xFF8B3A52),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...memories.asMap().entries.map(
                      (entry) => _PlaybackMemoryTile(
                        memory: entry.value,
                        onPlay: () => _openStory(memories, entry.key),
                        onOpen: () => _openDetail(entry.value),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlaybackIntro extends StatelessWidget {
  final String rangeLabel;
  final bool hasRange;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;

  const _PlaybackIntro({
    required this.rangeLabel,
    required this.hasRange,
    required this.onPickRange,
    required this.onClearRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE6ED), Color(0xFFFFF2F5)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A little story to revisit',
            style: TextStyle(
              color: Color(0xFF3D2C33),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Photos, videos and notes from the moments you want to hold close.',
            style: TextStyle(
              color: Color(0xFF8B3A52),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 17),
                label: Text(rangeLabel),
                onPressed: onPickRange,
                backgroundColor: Colors.white,
                side: BorderSide.none,
              ),
              if (hasRange)
                TextButton(
                  onPressed: onClearRange,
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Color(0xFF8B3A52)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaybackMemoryTile extends StatelessWidget {
  final Memory memory;
  final VoidCallback onPlay;
  final VoidCallback onOpen;

  const _PlaybackMemoryTile({
    required this.memory,
    required this.onPlay,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlayableMedia =
        memory.hasImage || (memory.hasVideo && memory.isVideoReady);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (memory.hasImage || memory.hasVideo) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: memory.hasVideo
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              YouTubeThumbnailImage(
                                videoId: memory.videoId!,
                                width: 74,
                                height: 74,
                              ),
                              if (memory.isVideoReady)
                                const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 28,
                                ),
                            ],
                          )
                        : CachedNetworkImage(
                            imageUrl: memory.feedThumbnailUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 160,
                            errorWidget: (_, __, ___) =>
                                const _TilePlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3D2C33),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${memory.mood}  ${memory.formattedDate}',
                      style: const TextStyle(
                        color: Color(0xFFB0889A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: hasPlayableMedia ? onPlay : onOpen,
                tooltip: hasPlayableMedia ? 'Play' : 'Open detail',
                icon: Icon(
                  hasPlayableMedia
                      ? Icons.play_circle_outline
                      : Icons.arrow_forward_ios_rounded,
                  color: const Color(0xFFE8A0B4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryStoryScreen extends StatefulWidget {
  final List<Memory> memories;
  final int initialIndex;
  final bool autoPlay;

  const MemoryStoryScreen({
    super.key,
    required this.memories,
    this.initialIndex = 0,
    this.autoPlay = true,
  });

  @override
  State<MemoryStoryScreen> createState() => _MemoryStoryScreenState();
}

class _MemoryStoryScreenState extends State<MemoryStoryScreen> {
  late final PageController _controller;
  late int _index;
  Timer? _timer;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.memories.length - 1).toInt();
    _controller = PageController(initialPage: _index);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoPlay());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    if (!mounted || !widget.autoPlay || _paused || widget.memories.length < 2) {
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_index >= widget.memories.length - 1) {
        _timer?.cancel();
        return;
      }
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseStory() {
    if (!widget.autoPlay) return;
    _timer?.cancel();
    if (mounted) setState(() => _paused = true);
  }

  void _resumeStory() {
    if (!widget.autoPlay) return;
    if (mounted) setState(() => _paused = false);
    _startAutoPlay();
  }

  void _nextStory() {
    if (_index >= widget.memories.length - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _startAutoPlay();
  }

  void _previousStory() {
    if (_index <= 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _startAutoPlay();
  }

  void _openVideo(Memory memory) {
    if (!memory.isVideoReady) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoId: memory.videoId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF24191E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF24191E),
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.memories.length}'),
        actions: [
          if (widget.autoPlay)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Icon(
                  Icons.pause_circle_outline,
                  size: 20,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final width = MediaQuery.sizeOf(context).width;
              if (details.localPosition.dx < width * 0.35) {
                _previousStory();
              } else if (details.localPosition.dx > width * 0.65) {
                _nextStory();
              }
            },
            onLongPressStart: (_) => _pauseStory(),
            onLongPressEnd: (_) => _resumeStory(),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.memories.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                _startAutoPlay();
              },
              itemBuilder: (_, index) {
                final memory = widget.memories[index];
                return _StoryPage(
                  memory: memory,
                  onPlayVideo: () => _openVideo(memory),
                );
              },
            ),
          ),
          Positioned(
            top: 10,
            left: 18,
            right: 18,
            child: Row(
              children: List.generate(widget.memories.length, (index) {
                final active = index == _index;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index == widget.memories.length - 1 ? 0 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white30,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (_paused)
            const Positioned(
              top: 28,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'Paused',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  final Memory memory;
  final VoidCallback onPlayVideo;

  const _StoryPage({required this.memory, required this.onPlayVideo});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: memory.hasVideo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            YouTubeThumbnailImage(
                              videoId: memory.videoId!,
                              width: double.infinity,
                              height: 300,
                            ),
                            if (memory.isVideoReady)
                              FloatingActionButton(
                                onPressed: onPlayVideo,
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF8B3A52),
                                child: const Icon(Icons.play_arrow_rounded),
                              ),
                          ],
                        ),
                      )
                    : memory.hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: PrivateDisplayImage(
                              memory: memory,
                              fit: BoxFit.contain,
                              loading: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE8A0B4),
                                ),
                              ),
                              error: const _StoryMediaError(),
                            ),
                          )
                        : _QuoteStoryCard(memory: memory),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${memory.mood}  ${memory.formattedDate}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                memory.note,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.65,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Added by ${memory.createdBy}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteStoryCard extends StatelessWidget {
  final Memory memory;

  const _QuoteStoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(28, 42, 28, 42),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE6ED), Color(0xFFFFF6F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: Color(0xFFB05A76), size: 42),
          const SizedBox(height: 18),
          Text(
            memory.note.isEmpty ? 'A quiet moment worth keeping.' : memory.note,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3D2C33),
              fontSize: 22,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackEmpty extends StatelessWidget {
  const _PlaybackEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, color: Color(0xFFE8A0B4), size: 58),
          SizedBox(height: 16),
          Text(
            'ဒီအချိန်အတွင်း memory မရှိသေးပါ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3D2C33),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'အခြားရက်စွဲကို ရွေးပါ၊ ဒါမှမဟုတ် Home ကနေ memory အသစ်ထည့်ပါ။',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB0889A), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  final String message;

  const _PlaybackError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: Color(0xFFE8A0B4), size: 52),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF3D2C33), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFE6ED),
      child: const Icon(Icons.photo_outlined, color: Color(0xFFE8A0B4)),
    );
  }
}

class _StoryMediaError extends StatelessWidget {
  const _StoryMediaError();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      color: Colors.white10,
      child: const Center(
        child:
            Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
      ),
    );
  }
}

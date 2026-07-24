import 'package:flutter/material.dart';

/// A YouTube video thumbnail that falls back gracefully when the primary CDN
/// URL returns an error (e.g. HTTP 403 caused by VPN filtering or CDN rate
/// limits).
///
/// Fallback order:
///   1. `https://img.youtube.com/vi/<id>/hqdefault.jpg`  (primary)
///   2. `https://i.ytimg.com/vi/<id>/hqdefault.jpg`      (alternate CDN)
///   3. `https://i.ytimg.com/vi/<id>/mqdefault.jpg`      (lower quality)
///   4. A local placeholder widget                        (always works)
///
/// Unlike a bare `Image.network`, this widget never surfaces raw HTTP status
/// strings to the user.
class YouTubeThumbnailImage extends StatefulWidget {
  final String videoId;
  final double? height;
  final double? width;
  final BoxFit fit;

  const YouTubeThumbnailImage({
    super.key,
    required this.videoId,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  State<YouTubeThumbnailImage> createState() => _YouTubeThumbnailImageState();
}

class _YouTubeThumbnailImageState extends State<YouTubeThumbnailImage> {
  int _urlIndex = 0;

  List<String> get _candidates => [
        'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg',
        'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
        'https://i.ytimg.com/vi/${widget.videoId}/mqdefault.jpg',
      ];

  void _onError() {
    if (!mounted) return;
    final next = _urlIndex + 1;
    if (next < _candidates.length) {
      setState(() => _urlIndex = next);
    } else {
      // All URLs exhausted — stay at last index; builder will show placeholder.
      setState(() => _urlIndex = _candidates.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_urlIndex >= _candidates.length) {
      return _Placeholder(
          height: widget.height ?? 200, width: widget.width ?? double.infinity);
    }

    return Image.network(
      _candidates[_urlIndex],
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _Loading(
            height: widget.height ?? 200,
            width: widget.width ?? double.infinity);
      },
      errorBuilder: (_, error, __) {
        debugPrint(
            '[YouTubeThumbnailImage] url #$_urlIndex failed for '
            'videoId=${widget.videoId}: $error');
        _onError();
        // Return the placeholder while setState re-renders.
        return _Placeholder(
            height: widget.height ?? 200,
            width: widget.width ?? double.infinity);
      },
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  final double height;
  final double width;
  const _Loading({required this.height, required this.width});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        color: const Color(0xFFFFE0E8),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE8A0B4),
            strokeWidth: 2,
          ),
        ),
      );
}

class _Placeholder extends StatelessWidget {
  final double height;
  final double width;
  const _Placeholder({required this.height, required this.width});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: Colors.white38, size: 40),
              SizedBox(height: 8),
              Text(
                'Thumbnail မရဘူး',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
}

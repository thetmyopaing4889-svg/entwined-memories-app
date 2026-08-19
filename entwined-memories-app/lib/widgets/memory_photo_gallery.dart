import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/display_media_service.dart';

/// Opens every image in a memory as an authenticated, swipeable R2 gallery.
Future<void> showMemoryPhotoGallery(
  BuildContext context, {
  required List<MemoryPhoto> photos,
  int initialPage = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MemoryPhotoGalleryScreen(
        photos: photos,
        initialPage: initialPage,
      ),
    ),
  );
}

/// Small gallery used in memory detail pages. The same R2-authenticated image
/// component is also used by the immersive full-screen viewer.
class MemoryPhotoGallery extends StatefulWidget {
  final List<MemoryPhoto> photos;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const MemoryPhotoGallery({
    super.key,
    required this.photos,
    required this.height,
    required this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  State<MemoryPhotoGallery> createState() => _MemoryPhotoGalleryState();
}

class _MemoryPhotoGalleryState extends State<MemoryPhotoGallery> {
  late final PageController _controller;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (_, index) => PrivateMemoryPhotoImage(
                photo: widget.photos[index],
                fit: widget.fit,
                loading: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE8A0B4)),
                ),
                error: const _PhotoError(),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                right: 10,
                bottom: 10,
                child: _PhotoCounter(
                    current: _page + 1, total: widget.photos.length),
              ),
          ],
        ),
      ),
    );
  }
}

class MemoryPhotoGalleryScreen extends StatefulWidget {
  final List<MemoryPhoto> photos;
  final int initialPage;

  const MemoryPhotoGalleryScreen({
    super.key,
    required this.photos,
    this.initialPage = 0,
  });

  @override
  State<MemoryPhotoGalleryScreen> createState() =>
      _MemoryPhotoGalleryScreenState();
}

class _MemoryPhotoGalleryScreenState extends State<MemoryPhotoGalleryScreen> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (_, index) => _ZoomableGalleryPhoto(
                photo: widget.photos[index],
                semanticsLabel:
                    'Memory photo ${index + 1} of ${widget.photos.length}',
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _CircleButton(
                icon: Icons.close_rounded,
                tooltip: 'Close photo gallery',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                top: 16,
                right: 16,
                child: _PhotoCounter(
                    current: _page + 1, total: widget.photos.length),
              ),
          ],
        ),
      ),
    );
  }
}

class PrivateMemoryPhotoImage extends StatefulWidget {
  final MemoryPhoto photo;
  final BoxFit fit;
  final Widget loading;
  final Widget error;

  const PrivateMemoryPhotoImage({
    super.key,
    required this.photo,
    required this.loading,
    required this.error,
    this.fit = BoxFit.contain,
  });

  @override
  State<PrivateMemoryPhotoImage> createState() =>
      _PrivateMemoryPhotoImageState();
}

class _PrivateMemoryPhotoImageState extends State<PrivateMemoryPhotoImage> {
  DisplayMediaRequest? _request;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrivateMemoryPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.displayMediaKey != widget.photo.displayMediaKey ||
        oldWidget.photo.feedThumbnailUrl != widget.photo.feedThumbnailUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _request = null;
    });
    try {
      if (widget.photo.hasPrivateDisplay) {
        _request = await DisplayMediaService.authorizedDisplayRequest(
          widget.photo.displayMediaKey!,
        );
      }
      if ((_request?.url ?? widget.photo.feedThumbnailUrl) == null) {
        _failed = true;
      }
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _request?.url ?? widget.photo.feedThumbnailUrl;
    if (_loading) return widget.loading;
    if (_failed || imageUrl == null) return widget.error;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: _request?.headers,
      fit: widget.fit,
      errorWidget: (_, __, ___) => widget.error,
    );
  }
}

class _ZoomableGalleryPhoto extends StatefulWidget {
  final MemoryPhoto photo;
  final String semanticsLabel;

  const _ZoomableGalleryPhoto({
    required this.photo,
    required this.semanticsLabel,
  });

  @override
  State<_ZoomableGalleryPhoto> createState() => _ZoomableGalleryPhotoState();
}

class _ZoomableGalleryPhotoState extends State<_ZoomableGalleryPhoto> {
  final _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformation,
      minScale: 1,
      maxScale: 4.5,
      child: Center(
        child: Semantics(
          image: true,
          label: widget.semanticsLabel,
          child: PrivateMemoryPhotoImage(
            photo: widget.photo,
            fit: BoxFit.contain,
            loading: const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8A0B4)),
            ),
            error: const _PhotoError(dark: true),
          ),
        ),
      ),
    );
  }
}

class _PhotoCounter extends StatelessWidget {
  final int current;
  final int total;

  const _PhotoCounter({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$current / $total',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _PhotoError extends StatelessWidget {
  final bool dark;

  const _PhotoError({this.dark = false});

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white70 : const Color(0xFF8B3A52);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: color, size: 44),
          const SizedBox(height: 8),
          Text('Photo ဖွင့်မရသေးဘူး', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

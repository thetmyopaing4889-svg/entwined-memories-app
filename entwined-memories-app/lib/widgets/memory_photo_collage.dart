import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/memory.dart';

/// A compact feed preview for a memory gallery. The full-resolution images are
/// intentionally never used here: each tile uses its Cloudinary feed thumbnail.
class MemoryPhotoCollage extends StatelessWidget {
  final List<MemoryPhoto> photos;
  final VoidCallback onTap;

  const MemoryPhotoCollage({
    super.key,
    required this.photos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    assert(photos.isNotEmpty);
    return Semantics(
      button: true,
      label:
          photos.length == 1
              ? 'Open memory photo full screen'
              : 'Open ${photos.length} memory photos full screen',
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(aspectRatio: 16 / 9, child: _layout(context)),
      ),
    );
  }

  Widget _layout(BuildContext context) {
    switch (photos.length) {
      case 1:
        return _PhotoTile(photo: photos.first);
      case 2:
        return Row(
          children: [
            Expanded(child: _PhotoTile(photo: photos[0])),
            const SizedBox(width: 2),
            Expanded(child: _PhotoTile(photo: photos[1])),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(flex: 3, child: _PhotoTile(photo: photos[0])),
            const SizedBox(width: 2),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: _PhotoTile(photo: photos[1])),
                  const SizedBox(height: 2),
                  Expanded(child: _PhotoTile(photo: photos[2])),
                ],
              ),
            ),
          ],
        );
      default:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _PhotoTile(photo: photos[0])),
                  const SizedBox(width: 2),
                  Expanded(child: _PhotoTile(photo: photos[1])),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _PhotoTile(photo: photos[2])),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _PhotoTile(
                      photo: photos[3],
                      remainingCount: photos.length - 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _PhotoTile extends StatelessWidget {
  final MemoryPhoto photo;
  final int remainingCount;

  const _PhotoTile({required this.photo, this.remainingCount = 0});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = photo.feedThumbnailUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: colors.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: colors.primary,
          size: 42,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 960,
          placeholder:
              (_, __) => Container(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: CircularProgressIndicator(
                    color: colors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
          errorWidget:
              (_, __, ___) => Container(
                color: colors.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.primary,
                  size: 42,
                ),
              ),
        ),
        if (remainingCount > 0)
          ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

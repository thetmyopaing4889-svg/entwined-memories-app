import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/display_media_service.dart';

/// Renders the private R2 display copy when it exists, with a Cloudinary
/// thumbnail fallback for legacy memories created before the dual-provider
/// migration. Downloaded files are retained by cached_network_image on device.
class PrivateDisplayImage extends StatefulWidget {
  final Memory memory;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget loading;
  final Widget error;

  const PrivateDisplayImage({
    super.key,
    required this.memory,
    required this.loading,
    required this.error,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  State<PrivateDisplayImage> createState() => _PrivateDisplayImageState();
}

class _PrivateDisplayImageState extends State<PrivateDisplayImage> {
  DisplayMediaRequest? _request;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrivateDisplayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memory.displayMediaKey != widget.memory.displayMediaKey ||
        oldWidget.memory.feedThumbnailUrl != widget.memory.feedThumbnailUrl) {
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
      if (widget.memory.hasPrivateDisplay) {
        _request = await DisplayMediaService.authorizedDisplayRequest(
          widget.memory.displayMediaKey!,
        );
      }
      if ((_request?.url ?? widget.memory.feedThumbnailUrl) == null) {
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
    final imageUrl = _request?.url ?? widget.memory.feedThumbnailUrl;
    final content = _loading
        ? widget.loading
        : _failed || imageUrl == null
            ? widget.error
            : CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: _request?.headers,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                errorWidget: (_, __, ___) => widget.error,
              );

    if (widget.width != null || widget.height != null) {
      return SizedBox(
          width: widget.width, height: widget.height, child: content);
    }
    return content;
  }
}

import 'package:flutter/material.dart';

/// Opens an immersive image viewer with pinch-to-zoom, panning, reset, and a
/// clear close affordance. The caller supplies the same [ImageProvider] used
/// by its compact photo widget, so both local cropped files and remote images
/// can be previewed without duplicating image-loading logic.
Future<void> showFullScreenPhotoViewer(
  BuildContext context, {
  required ImageProvider imageProvider,
  String semanticsLabel = 'Full screen photo preview',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => FullScreenPhotoViewer(
        imageProvider: imageProvider,
        semanticsLabel: semanticsLabel,
      ),
    ),
  );
}

class FullScreenPhotoViewer extends StatefulWidget {
  final ImageProvider imageProvider;
  final String semanticsLabel;

  const FullScreenPhotoViewer({
    super.key,
    required this.imageProvider,
    required this.semanticsLabel,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1,
                maxScale: 4.5,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionEnd: (_) => setState(() {}),
                child: Semantics(
                  image: true,
                  label: widget.semanticsLabel,
                  child: Image(
                    image: widget.imageProvider,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              color: Colors.white70, size: 52),
                          SizedBox(height: 12),
                          Text(
                            'Photo ဖွင့်မရသေးဘူး',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _ViewerButton(
                icon: Icons.close_rounded,
                tooltip: 'Close photo preview',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _ViewerButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Reset zoom',
                onPressed: _resetZoom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ViewerButton({
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

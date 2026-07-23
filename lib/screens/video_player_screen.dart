import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen in-app player for a memory's YouTube video.
///
/// Uses [WebView] + the standard YouTube embed URL
/// (youtube.com/embed/{videoId}) instead of the IFrame API wrapper so
/// that the embedded player works reliably on all Android versions without
/// origin-restriction errors (101 / 150).
class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    final embedUrl =
        'https://www.youtube.com/embed/${widget.videoId}'
        '?autoplay=1&playsinline=1&controls=1&rel=0';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 11; Mobile) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint(
                '[VideoPlayerScreen] WebView error: ${error.description}');
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl));
  }

  @override
  void dispose() {
    // Restore orientation and system UI in case the user went full-screen.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Memory Video'),
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('😔', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 20),
                    const Text(
                      'Video ဖွင့်မရဘူး',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Network စစ်ပြီး ထပ်ကြိုးစားပါ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.white60, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('နောက်သွားမယ်',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),

          // Loading indicator
          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE8A0B4),
              ),
            ),
        ],
      ),
    );
  }
}

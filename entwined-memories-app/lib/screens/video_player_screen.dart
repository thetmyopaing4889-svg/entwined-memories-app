import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen in-app player for a memory's YouTube video.
///
/// Uses [WebView] + a locally-generated HTML wrapper page so that Android
/// WebView sends the correct HTTP `Referer` and `Origin` headers that YouTube
/// requires.
///
/// YouTube's Required Minimum Functionality spec (see
/// https://developers.google.com/youtube/terms/required-minimum-functionality)
/// says that in a WebView integration where no browser sets the Referer
/// automatically, the app must supply it.  The `Referer` value must be the
/// app's Android Application-ID formatted as an HTTPS URL
/// (e.g. `https://com.entwinedmemories.entwined_memories`).
///
/// Using `https://www.youtube.com` as the Referer triggers stricter embed
/// rules and causes Error 152-4 ("This video is unavailable").
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
  bool _showPlayFallback = true;

  /// The app's Android Application-ID expressed as an HTTPS URL.
  ///
  /// YouTube uses this as the embedding-page identity so the player can be
  /// authorised for embedded playback.  This value must be stable across app
  /// versions and must *not* be `https://www.youtube.com`.
  static const _appReferrer =
      'https://com.entwinedmemories.entwined_memories';

  /// Build the local HTML page that hosts the YouTube IFrame.
  ///
  /// Key attributes that resolve Error 152-4 and Error 153:
  ///  - `<meta name="referrer" content="strict-origin-when-cross-origin">` —
  ///    ensures subsequent sub-resource requests carry the correct Referer.
  ///  - `referrerpolicy="strict-origin-when-cross-origin"` on the `<iframe>`.
  ///  - `origin=<appReferrer>` query parameter — matches the Referer the
  ///    IFrame Player API expects for PostMessage authentication.
  ///  - `youtube-nocookie.com` domain — privacy-enhanced endpoint; also
  ///    recommended by YouTube for embedded players.
  String _buildHtml({required bool autoplay}) {
    final src = Uri(
      scheme: 'https',
      host: 'www.youtube-nocookie.com',
      path: '/embed/${widget.videoId}',
      queryParameters: {
        'autoplay': autoplay ? '1' : '0',
        'playsinline': '1',
        'controls': '1',
        'rel': '0',
        'enablejsapi': '1',
        'origin': _appReferrer,
      },
    ).toString();

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    .wrap { position: relative; width: 100%; height: 100%; }
    iframe {
      position: absolute; top: 0; left: 0;
      width: 100%; height: 100%; border: none;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <iframe
      src="$src"
      allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
      allowfullscreen
      referrerpolicy="strict-origin-when-cross-origin"
      frameborder="0">
    </iframe>
  </div>
</body>
</html>''';
  }

  Future<void> _loadEmbed({required bool autoplay}) {
    return _controller.loadHtmlString(
      _buildHtml(autoplay: autoplay),
      baseUrl: _appReferrer,
    );
  }

  @override
  void initState() {
    super.initState();

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
            // Only a failed main-frame load means the player itself failed.
            if (error.isForMainFrame != true) return;
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadHtmlString(
        _buildHtml(autoplay: true),
        baseUrl: _appReferrer,
      );
  }

  Future<void> _playFromUserGesture() async {
    if (!mounted) return;
    setState(() {
      _showPlayFallback = false;
      _isLoading = true;
      _hasError = false;
    });
    // Reloading after a real tap gives Android WebView permission to start
    // media when autoplay was blocked on the first navigation.
    await _loadEmbed(autoplay: true);
  }

  @override
  void dispose() {
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
                    ElevatedButton.icon(
                      onPressed: _playFromUserGesture,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ထပ်ကြိုးစားမယ်'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A0B4),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('နောက်သွားမယ်',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            WebViewWidget(controller: _controller),
            if (_showPlayFallback && !_isLoading)
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _playFromUserGesture,
                    borderRadius: BorderRadius.circular(40),
                    child: Ink(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
          ],

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

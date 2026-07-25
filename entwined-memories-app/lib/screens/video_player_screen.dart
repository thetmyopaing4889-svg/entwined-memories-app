import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen in-app player for a memory's YouTube video.
///
/// Primary: plays the video inside a WebView using the youtube-nocookie.com
/// embed endpoint with the correct app-ID Referer so YouTube authorises it.
///
/// If the embed fails (Error 153 / 152-4 / network error) the user sees a
/// retry button.  No external app or browser is ever launched.
class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _controller;
  int _loadAttempt = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showPlayFallback = true;

  /// App ID as an HTTPS URL — YouTube uses this as the embedding-page
  /// identity.  Must match the Android applicationId and must NOT be
  /// https://www.youtube.com.
  static const _appReferrer =
      'https://com.entwinedmemories.entwined_memories';

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
      onload="document.body.setAttribute('data-player-frame-loaded', 'true')"
      allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
      allowfullscreen
      referrerpolicy="strict-origin-when-cross-origin"
      frameborder="0">
    </iframe>
  </div>
</body>
</html>''';
  }

  Future<void> _loadEmbed({required bool autoplay}) async {
    final attempt = ++_loadAttempt;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    await _controller.loadHtmlString(
      _buildHtml(autoplay: autoplay),
      baseUrl: _appReferrer,
    );

    // loadHtmlString finishes when the local wrapper is ready, not when the
    // remote iframe has loaded.  Poll for the iframe's own onload marker so
    // the loading spinner stays up until the player is actually visible, then
    // time-out after 15 s and show the error/retry screen.
    var frameLoaded = false;
    for (var i = 0; i < 60 && mounted && attempt == _loadAttempt; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        final marker = await _controller.runJavaScriptReturningResult(
          "document.body.getAttribute('data-player-frame-loaded')",
        );
        if (marker.toString().replaceAll('"', '') == 'true') {
          frameLoaded = true;
          break;
        }
      } catch (_) {
        // JS context may not be ready yet — keep polling.
      }
    }

    if (!mounted || attempt != _loadAttempt) return;
    setState(() {
      _isLoading = false;
      if (!frameLoaded) _hasError = true;
    });
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          // Local wrapper finishes before the iframe — _loadEmbed handles
          // the real "ready" signal via the JS marker.
          onPageFinished: (_) {},
          onWebResourceError: (error) {
            debugPrint(
                '[VideoPlayerScreen] WebView error: ${error.description}');
            if (error.isForMainFrame != true) return;
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onHttpError: (error) {
            debugPrint(
                '[VideoPlayerScreen] HTTP ${error.response?.statusCode}'
                ': ${error.request?.uri}');
            final code = error.response?.statusCode;
            final host = error.request?.uri.host;
            if (code != null &&
                code >= 400 &&
                host != null &&
                (host == 'www.youtube-nocookie.com' ||
                    host.endsWith('.youtube-nocookie.com'))) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            }
          },
        ),
      );

    unawaited(_loadEmbed(autoplay: true));
  }

  Future<void> _playFromUserGesture() async {
    if (!mounted) return;
    setState(() => _showPlayFallback = false);
    await _loadEmbed(autoplay: true);
  }

  @override
  void dispose() {
    _loadAttempt++;
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Video processing မပြီးသေးတာ ဖြစ်နိုင်တယ်။\n'
                      'မိနစ်အနည်းငယ်နောက်မှ ထပ်ကြိုးစားပါ။',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                        height: 1.6,
                      ),
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
                      child: const Text(
                        'နောက်သွားမယ်',
                        style: TextStyle(color: Colors.white54),
                      ),
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

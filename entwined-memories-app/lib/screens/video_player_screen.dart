import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a memory video in YouTube's official Android app or the device
/// browser.
///
/// YouTube can challenge embedded Android WebViews with
/// "Sign in to confirm you're not a bot", especially when the device is using
/// a VPN or a flagged shared IP. That challenge is enforced by YouTube's
/// servers and cannot be made reliable by changing iframe headers. Opening
/// the normal YouTube URL lets Android use the official YouTube client or a
/// full browser session instead of an anonymous embedded WebView.
class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isOpening = true;
  bool _launchFailed = false;
  bool _hasOpened = false;

  Uri get _watchUrl => Uri.https(
        'www.youtube.com',
        '/watch',
        {'v': widget.videoId},
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openOfficialPlayer());
    });
  }

  Future<void> _openOfficialPlayer() async {
    if (!mounted || (_isOpening && _hasOpened)) return;

    setState(() {
      _isOpening = true;
      _launchFailed = false;
    });

    var opened = false;
    try {
      opened = await launchUrl(
        _watchUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('[VideoPlayerScreen] Failed to launch YouTube: $error');
    }

    if (!mounted) return;
    setState(() {
      _isOpening = false;
      _launchFailed = !opened;
      _hasOpened = opened;
    });
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _launchFailed ? Icons.error_outline : Icons.ondemand_video,
                color: const Color(0xFFE8A0B4),
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                _isOpening
                    ? 'YouTube ကို ဖွင့်နေပါတယ်...'
                    : _launchFailed
                        ? 'YouTube မဖွင့်နိုင်သေးဘူး'
                        : 'YouTube မှာ ဖွင့်ပြီးပါပြီ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _launchFailed
                    ? 'YouTube app သို့မဟုတ် browser ရှိမရှိ စစ်ပြီး ထပ်ကြိုးစားပါ။'
                    : 'YouTube ရဲ့ official player နဲ့ဖွင့်ထားပါတယ်။ '
                      'VPN ဖွင့်ထားရင် ပိတ်ပြီး စမ်းပါ။',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              if (_isOpening)
                const CircularProgressIndicator(
                  color: Color(0xFFE8A0B4),
                )
              else
                ElevatedButton.icon(
                  onPressed: _openOfficialPlayer,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    _launchFailed
                        ? 'YouTube မှာ ထပ်ဖွင့်မယ်'
                        : 'YouTube ကို ပြန်ဖွင့်မယ်',
                  ),
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
      ),
    );
  }
}

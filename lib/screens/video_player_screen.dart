import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Full-screen in-app player for a memory's YouTube video.
///
/// YouTube is used purely as backend video storage/streaming — the user
/// never leaves the app or sees the YouTube UI/branding beyond the embedded
/// player controls themselves.
class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[VideoPlayerScreen] initializing in-app player for videoId="${widget.videoId}"');
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false,
        controlsVisibleAtStart: true,
      ),
    )..addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    if (_controller.value.hasError) {
      debugPrint(
          '[VideoPlayerScreen] player error for videoId="${widget.videoId}": '
          '${_controller.value.errorCode}');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    // Restore normal orientation/system UI in case the player locked
    // landscape while in fullscreen mode.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFFE8A0B4),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFFE8A0B4),
          handleColor: Color(0xFFE8A0B4),
        ),
        onReady: () {
          debugPrint(
              '[VideoPlayerScreen] player ready for videoId="${widget.videoId}"');
        },
        onEnded: (_) {
          debugPrint(
              '[VideoPlayerScreen] playback ended for videoId="${widget.videoId}"');
        },
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Memory Video'),
          ),
          body: Center(child: player),
        );
      },
    );
  }
}

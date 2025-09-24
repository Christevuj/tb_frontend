import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SharedYoutubePlayer extends StatefulWidget {
  const SharedYoutubePlayer({super.key});

  @override
  State<SharedYoutubePlayer> createState() => _SharedYoutubePlayerState();
}

class _SharedYoutubePlayerState extends State<SharedYoutubePlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    const url = "https://www.youtube.com/watch?v=VCPngZ5oxGI";
    final id = YoutubePlayer.convertUrlToId(url)!;

    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
      ),
    );
  }
}

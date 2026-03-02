import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter/services.dart';
import 'package:pip_view/pip_view.dart';

class PlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final Duration initialPosition;
  final Function(Duration) onProgressUpdate;

  const PlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.initialPosition = Duration.zero,
    required this.onProgressUpdate,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VlcPlayerController _vlcViewController;
  bool _showControls = true;
  double _aspectRatio = 16 / 9;
  bool _hasSeeked = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _vlcViewController = VlcPlayerController.network(
      widget.videoUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
         advanced: VlcAdvancedOptions([
           VlcAdvancedOptions.networkCaching(2000),
         ]),
      ),
    );

    _vlcViewController.addListener(_onVlcChange);
    _startHideTimer();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _onVlcChange() {
    if (_vlcViewController.value.isInitialized && !_hasSeeked && widget.initialPosition > Duration.zero) {
      _hasSeeked = true;
      _vlcViewController.setTime(widget.initialPosition.inMilliseconds);
    }
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _vlcViewController.removeListener(_onVlcChange);
    _vlcViewController.getPosition().then((pos) {
       widget.onProgressUpdate(pos);
    });
    _vlcViewController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  void _cycleAspectRatio() {
    setState(() {
      if (_aspectRatio == 16 / 9) {
        _aspectRatio = 21 / 9;
      } else if (_aspectRatio == 21 / 9) {
        _aspectRatio = 4 / 3;
      } else {
        _aspectRatio = 16 / 9;
      }
    });
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return PIPView(
      builder: (context, isFloating) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isFloating ? null : _toggleControls,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: VlcPlayer(
                    controller: _vlcViewController,
                    aspectRatio: _aspectRatio,
                    placeholder: const Center(child: CircularProgressIndicator()),
                  ),
                ),
                if (_showControls && !isFloating)
                  _buildControlsOverlay(),
                if (_vlcViewController.value.hasError)
                   Center(child: Text('Erro ao carregar vídeo: ${_vlcViewController.value.errorDescription}', style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildControlsOverlay() {
    final position = _vlcViewController.value.position;
    final duration = _vlcViewController.value.duration;

    return Container(
      color: Colors.black45,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
               IconButton(
                icon: const Icon(Icons.aspect_ratio),
                onPressed: _cycleAspectRatio,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               IconButton(
                iconSize: 64,
                icon: Icon(
                   _vlcViewController.value.isPlaying ? Icons.pause : Icons.play_arrow,
                   color: Colors.white,
                ),
                onPressed: () {
                   setState(() {
                     _vlcViewController.value.isPlaying
                        ? _vlcViewController.pause()
                        : _vlcViewController.play();
                   });
                   _startHideTimer();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Slider(
                  activeColor: Colors.purple,
                  inactiveColor: Colors.white24,
                  value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble()),
                  max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0,
                  onChanged: (value) {
                    _vlcViewController.setTime(Duration(seconds: value.toInt()).inMilliseconds);
                    _startHideTimer();
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture, color: Colors.white),
                      onPressed: () {
                        PIPView.of(context)!.presentBelow(Container());
                      },
                    ),
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

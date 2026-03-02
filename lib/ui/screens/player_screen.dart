import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        startAt: widget.initialPosition,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.purple,
          handleColor: Colors.purpleAccent,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  void dispose() {
    if (_videoPlayerController != null) {
       widget.onProgressUpdate(_videoPlayerController!.value.position);
    }
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PIPView(
      builder: (context, isFloating) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: isFloating ? null : AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(widget.title, style: const TextStyle(fontSize: 14)),
          ),
          extendBodyBehindAppBar: true,
          body: _buildBody(isFloating),
        );
      }
    );
  }

  Widget _buildBody(bool isFloating) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 10),
            const Text('ERRO AO CARREGAR VÍDEO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('VOLTAR')),
          ],
        ),
      );
    }

    if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
       return Chewie(controller: _chewieController!);
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 10),
          Text('Carregando...', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

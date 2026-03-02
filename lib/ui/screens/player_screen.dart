import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  bool _hasError = false;
  String _errorMsg = '';
  bool _isInitialized = false;

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
      player.stream.error.listen((event) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMsg = event; // event is String in media_kit
          });
        }
      });

      player.stream.completed.listen((completed) {
        if (completed && mounted) {
           Navigator.pop(context);
        }
      });

      await player.open(Media(widget.videoUrl), play: true);

      if (widget.initialPosition > Duration.zero) {
        await player.seek(widget.initialPosition);
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  void dispose() {
    widget.onProgressUpdate(player.state.position);
    player.dispose();
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

    if (_isInitialized) {
       return Video(
         controller: controller,
         fill: Colors.black,
       );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 10),
          Text('Carregando com MediaKit...', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

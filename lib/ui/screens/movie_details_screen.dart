import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/movie_provider.dart';
import '../../models/movie_models.dart';
import '../widgets/app_image.dart';
import 'player_screen.dart';
import 'web_player_screen.dart';
import '../../services/native_player_service.dart';
import '../../services/telegram_service.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                AppImage(
                  path: movie.backdropPath.isNotEmpty ? movie.backdropPath : movie.posterPath,
                  height: 300,
                  width: double.infinity,
                ),
                Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xFF000010)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(movie.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 5),
                      Text('${movie.voteAverage.toStringAsFixed(1)} / 10'),
                      const SizedBox(width: 20),
                      Text(movie.releaseDate.isNotEmpty ? movie.releaseDate.split('-')[0] : 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => _play(context, false),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ASSISTIR'),
                  ),
                  if (movie.webPlayerUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.white),
                      ),
                      onPressed: () => _play(context, true),
                      icon: const Icon(Icons.language),
                      label: const Text('ASSISTIR (WEB PLAYER)'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Sinopse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(movie.overview, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _play(BuildContext context, bool useWeb) async {
    final provider = context.read<MovieProvider>();
    String effectiveUrl = movie.videoUrl;

    if (movie.isTelegram && movie.telegramFileId != null) {
       await TelegramService.startProxy();
       effectiveUrl = TelegramService.getProxyUrl(movie.telegramFileId!);
    }

    if (useWeb) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WebPlayerScreen(url: movie.webPlayerUrl, title: movie.title)),
      );
      return;
    }

    if (provider.useNativePlayer) {
      final newPos = await NativePlayerService.playVideo(effectiveUrl, movie.title, movie.watchProgress);
      provider.updateMovieProgress(movie.id!, newPos);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            videoUrl: effectiveUrl,
            title: movie.title,
            initialPosition: Duration(milliseconds: movie.watchProgress),
            onProgressUpdate: (pos) {
              provider.updateMovieProgress(movie.id!, pos.inMilliseconds);
            },
          ),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/movie_models.dart';
import '../../providers/movie_provider.dart';
import 'player_screen.dart';

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
                CachedNetworkImage(
                  imageUrl: movie.backdropPath.isNotEmpty ? movie.backdropPath : movie.posterPath,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                      Text(movie.releaseDate.split('-')[0]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          videoUrl: movie.videoUrl,
                          title: movie.title,
                          initialPosition: Duration(milliseconds: movie.watchProgress),
                          onProgressUpdate: (pos) {
                            context.read<MovieProvider>().updateMovieProgress(movie.id!, pos.inMilliseconds);
                          },
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ASSISTIR'),
                  ),
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
}

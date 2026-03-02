import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/movie_provider.dart';
import '../../models/movie_models.dart';
import '../widgets/app_image.dart';
import 'add_item_screen.dart';
import 'movie_details_screen.dart';
import 'series_details_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<MovieProvider>().fetchMovies();
      context.read<MovieProvider>().fetchSeriesList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Local Movie Player', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
           IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) {
              context.read<MovieProvider>().fetchMovies();
              context.read<MovieProvider>().fetchSeriesList();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddItemScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeroBanner(),
            const SizedBox(height: 20),
            _MovieSection(title: 'Meus Filmes'),
            const SizedBox(height: 20),
            _SeriesSection(title: 'Minhas Séries'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final movieProvider = context.watch<MovieProvider>();
    final movies = movieProvider.movies;

    if (movies.isEmpty) {
      return Container(
        height: 500,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade900, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie, size: 100, color: Colors.white24),
              const SizedBox(height: 10),
              const Text('Nenhum conteúdo adicionado', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddItemScreen()),
                ),
                child: const Text('Adicionar Filme ou Série'),
              ),
            ],
          ),
        ),
      );
    }

    final featured = movies.first;

    return Stack(
      children: [
        Container(
          height: 500,
          width: double.infinity,
          foregroundDecoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xFF000010)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.6, 1.0],
            ),
          ),
          child: AppImage(
            path: featured.backdropPath.isNotEmpty ? featured.backdropPath : featured.posterPath,
          ),
        ),
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                featured.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: featured)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ASSISTIR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieSection extends StatelessWidget {
  final String title;
  const _MovieSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final movies = context.watch<MovieProvider>().movies;
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)),
                ),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppImage(path: movie.posterPath),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeriesSection extends StatelessWidget {
  final String title;
  const _SeriesSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final seriesList = context.watch<MovieProvider>().seriesList;
    if (seriesList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: seriesList.length,
            itemBuilder: (context, index) {
              final series = seriesList[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: series)),
                ),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppImage(path: series.posterPath),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

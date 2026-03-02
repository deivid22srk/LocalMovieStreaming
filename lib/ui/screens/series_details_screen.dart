import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/movie_models.dart';
import '../../services/database_service.dart';
import '../../providers/movie_provider.dart';
import 'player_screen.dart';

class SeriesDetailsScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailsScreen({super.key, required this.series});

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Season> _seasons = [];
  Map<int, List<Episode>> _episodes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final seasons = await _dbService.getSeasons(widget.series.id!);
    for (var season in seasons) {
      final episodes = await _dbService.getEpisodes(season.id!);
      _episodes[season.id!] = episodes;
    }
    if (mounted) {
      setState(() {
        _seasons = seasons;
        _isLoading = false;
      });
    }
  }

  void _editEpisode(Episode ep) {
    final TextEditingController urlCtrl = TextEditingController(text: ep.videoUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Episódio ${ep.episodeNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL do Vídeo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
               await context.read<MovieProvider>().updateEpisodeUrl(ep.id!, urlCtrl.text);
               Navigator.pop(context);
               _loadData();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: widget.series.backdropPath.isNotEmpty ? widget.series.backdropPath : widget.series.posterPath,
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
                  child: Text(widget.series.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
                      Text('${widget.series.voteAverage.toStringAsFixed(1)} / 10'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(widget.series.overview, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70)),
                  const SizedBox(height: 30),
                  const Text('Temporadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ..._seasons.map((season) => ExpansionTile(
                    title: Text(season.title),
                    children: [
                      ...?_episodes[season.id!]?.map((ep) => ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text('${ep.episodeNumber}. ${ep.title}'),
                        subtitle: ep.videoUrl.isEmpty ? const Text('Sem URL - toque para editar', style: TextStyle(color: Colors.redAccent, fontSize: 12)) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ep.watchProgress > 0) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _editEpisode(ep)),
                          ],
                        ),
                        onTap: ep.videoUrl.isEmpty ? () => _editEpisode(ep) : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              videoUrl: ep.videoUrl,
                              title: ep.title,
                              initialPosition: Duration(milliseconds: ep.watchProgress),
                              onProgressUpdate: (pos) {
                                context.read<MovieProvider>().updateEpisodeProgress(ep.id!, pos.inMilliseconds);
                              },
                            ),
                          ),
                        ).then((_) => _loadData()),
                      )).toList(),
                    ],
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/movie_models.dart';
import '../../services/database_service.dart';
import '../../providers/movie_provider.dart';
import '../widgets/app_image.dart';
import 'player_screen.dart';
import 'web_player_screen.dart';
import '../../services/native_player_service.dart';
import '../../services/telegram_service.dart';

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

  void _addSeason() async {
    final num = _seasons.length + 1;
    await _dbService.insertSeason(Season(
      seriesId: widget.series.id!,
      seasonNumber: num,
      title: 'Temporada $num',
      overview: '',
      posterPath: widget.series.posterPath,
    ));
    _loadData();
  }

  void _addEpisode(Season season) {
    final TextEditingController urlCtrl = TextEditingController();
    final TextEditingController webUrlCtrl = TextEditingController();
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController imageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Novo Episódio - ${season.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL do Vídeo')),
              TextField(controller: webUrlCtrl, decoration: const InputDecoration(labelText: 'URL Player Web')),
              Row(
                children: [
                  Expanded(child: TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Imagem'))),
                  IconButton(
                    icon: const Icon(Icons.file_open),
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null) imageCtrl.text = result.files.single.path!;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
               final num = (_episodes[season.id!]?.length ?? 0) + 1;
               await _dbService.insertEpisode(Episode(
                 seasonId: season.id!,
                 episodeNumber: num,
                 title: titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Episódio $num',
                 overview: '',
                 stillPath: imageCtrl.text,
                 videoUrl: urlCtrl.text,
                 webPlayerUrl: webUrlCtrl.text,
               ));
               Navigator.pop(context);
               _loadData();
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _editEpisode(Episode ep) {
    final TextEditingController urlCtrl = TextEditingController(text: ep.videoUrl);
    final TextEditingController webUrlCtrl = TextEditingController(text: ep.webPlayerUrl);
    final TextEditingController titleCtrl = TextEditingController(text: ep.title);
    final TextEditingController imageCtrl = TextEditingController(text: ep.stillPath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Episódio ${ep.episodeNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL do Vídeo')),
              TextField(controller: webUrlCtrl, decoration: const InputDecoration(labelText: 'URL Player Web')),
              Row(
                children: [
                  Expanded(child: TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Imagem'))),
                  IconButton(
                    icon: const Icon(Icons.file_open),
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null) imageCtrl.text = result.files.single.path!;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
               final updatedEp = Episode(
                 id: ep.id,
                 seasonId: ep.seasonId,
                 episodeNumber: ep.episodeNumber,
                 title: titleCtrl.text,
                 overview: ep.overview,
                 stillPath: imageCtrl.text,
                 videoUrl: urlCtrl.text,
                 webPlayerUrl: webUrlCtrl.text,
                 watchProgress: ep.watchProgress,
                 duration: ep.duration,
               );
               await _dbService.updateEpisode(updatedEp);
               Navigator.pop(context);
               _loadData();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _play(Episode ep, bool useWeb) async {
    final provider = context.read<MovieProvider>();
    String effectiveUrl = ep.videoUrl;

    if (ep.isTelegram && ep.telegramFileId != null) {
       await TelegramService.startProxy();
       effectiveUrl = TelegramService.getProxyUrl(ep.telegramFileId!, accessHash: ep.telegramAccessHash);
    }

    if (useWeb) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WebPlayerScreen(url: ep.webPlayerUrl, title: '${widget.series.title} - ${ep.title}')),
      );
      return;
    }

    if (provider.useNativePlayer) {
      final newPos = await NativePlayerService.playVideo(effectiveUrl, ep.title, ep.watchProgress);
      provider.updateEpisodeProgress(ep.id!, newPos);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            videoUrl: effectiveUrl,
            title: ep.title,
            initialPosition: Duration(milliseconds: ep.watchProgress),
            onProgressUpdate: (pos) {
              provider.updateEpisodeProgress(ep.id!, pos.inMilliseconds);
            },
          ),
        ),
      ).then((_) => _loadData());
    }
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
                AppImage(
                  path: widget.series.backdropPath.isNotEmpty ? widget.series.backdropPath : widget.series.posterPath,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Temporadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addSeason),
                    ],
                  ),
                  const Divider(),
                  ..._seasons.map((season) => ExpansionTile(
                    title: Text(season.title),
                    children: [
                      ...?_episodes[season.id!]?.map((ep) => ListTile(
                        leading: ep.stillPath.isNotEmpty
                           ? AppImage(path: ep.stillPath, width: 60, height: 40)
                           : const Icon(Icons.play_circle_outline),
                        title: Text('${ep.episodeNumber}. ${ep.title}'),
                        subtitle: ep.videoUrl.isEmpty && ep.webPlayerUrl.isEmpty
                           ? const Text('Sem URL - toque para editar', style: TextStyle(color: Colors.redAccent, fontSize: 12))
                           : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ep.watchProgress > 0) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _editEpisode(ep)),
                            if (ep.webPlayerUrl.isNotEmpty)
                               IconButton(icon: const Icon(Icons.language, size: 16), onPressed: () => _play(ep, true)),
                          ],
                        ),
                        onTap: (ep.videoUrl.isEmpty && ep.webPlayerUrl.isEmpty)
                           ? () => _editEpisode(ep)
                           : () => _play(ep, false),
                      )).toList(),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Adicionar Episódio'),
                        onTap: () => _addEpisode(season),
                      ),
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

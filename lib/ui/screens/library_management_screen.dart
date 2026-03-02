import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/movie_models.dart';
import '../../providers/movie_provider.dart';
import '../widgets/app_image.dart';

class LibraryManagementScreen extends StatefulWidget {
  const LibraryManagementScreen({super.key});

  @override
  State<LibraryManagementScreen> createState() => _LibraryManagementScreenState();
}

class _LibraryManagementScreenState extends State<LibraryManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final movieProvider = context.watch<MovieProvider>();
    final movies = movieProvider.movies;
    final seriesList = movieProvider.seriesList;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gerenciar Biblioteca'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'FILMES'),
              Tab(text: 'SÉRIES'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMovieList(movies),
            _buildSeriesList(seriesList),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieList(List<Movie> movies) {
    if (movies.isEmpty) return const Center(child: Text('Nenhum filme adicionado.'));

    return ListView.builder(
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return ListTile(
          leading: AppImage(path: movie.posterPath, width: 40),
          title: Text(movie.title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editMovie(movie)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteMovie(movie.id!)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeriesList(List<Series> seriesList) {
    if (seriesList.isEmpty) return const Center(child: Text('Nenhuma série adicionada.'));

    return ListView.builder(
      itemCount: seriesList.length,
      itemBuilder: (context, index) {
        final series = seriesList[index];
        return ListTile(
          leading: AppImage(path: series.posterPath, width: 40),
          title: Text(series.title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editSeries(series)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteSeries(series.id!)),
            ],
          ),
        );
      },
    );
  }

  void _editMovie(Movie movie) {
    final titleCtrl = TextEditingController(text: movie.title);
    final overviewCtrl = TextEditingController(text: movie.overview);
    final urlCtrl = TextEditingController(text: movie.videoUrl);
    final posterCtrl = TextEditingController(text: movie.posterPath);
    final backdropCtrl = TextEditingController(text: movie.backdropPath);
    final dateCtrl = TextEditingController(text: movie.releaseDate);
    final ratingCtrl = TextEditingController(text: movie.voteAverage.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Filme Completo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: overviewCtrl, decoration: const InputDecoration(labelText: 'Sinopse'), maxLines: 3),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL do Vídeo')),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Data de Lançamento')),
              TextField(controller: ratingCtrl, decoration: const InputDecoration(labelText: 'Avaliação (0-10)')),
              const SizedBox(height: 10),
              _buildPickerRow('Capa', posterCtrl),
              const SizedBox(height: 10),
              _buildPickerRow('Banner', backdropCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final updated = Movie(
                id: movie.id,
                title: titleCtrl.text,
                overview: overviewCtrl.text,
                posterPath: posterCtrl.text,
                backdropPath: backdropCtrl.text,
                videoUrl: urlCtrl.text,
                voteAverage: double.tryParse(ratingCtrl.text) ?? 0.0,
                releaseDate: dateCtrl.text,
                watchProgress: movie.watchProgress,
                duration: movie.duration,
              );
              await context.read<MovieProvider>().updateMovieFull(updated);
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerRow(String label, TextEditingController controller) {
     return Row(
        children: [
          Expanded(child: TextField(controller: controller, decoration: InputDecoration(labelText: label))),
          IconButton(icon: const Icon(Icons.file_open), onPressed: () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
            if (result != null) controller.text = result.files.single.path!;
          }),
        ],
      );
  }

  void _editSeries(Series series) {
     final titleCtrl = TextEditingController(text: series.title);
     final overviewCtrl = TextEditingController(text: series.overview);
     final posterCtrl = TextEditingController(text: series.posterPath);
     final backdropCtrl = TextEditingController(text: series.backdropPath);
     final dateCtrl = TextEditingController(text: series.firstAirDate);
     final ratingCtrl = TextEditingController(text: series.voteAverage.toString());

     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Série Completa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: overviewCtrl, decoration: const InputDecoration(labelText: 'Sinopse'), maxLines: 3),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Data de Lançamento')),
              TextField(controller: ratingCtrl, decoration: const InputDecoration(labelText: 'Avaliação (0-10)')),
              const SizedBox(height: 10),
              _buildPickerRow('Capa', posterCtrl),
              const SizedBox(height: 10),
              _buildPickerRow('Banner', backdropCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final updated = Series(
                id: series.id,
                title: titleCtrl.text,
                overview: overviewCtrl.text,
                posterPath: posterCtrl.text,
                backdropPath: backdropCtrl.text,
                voteAverage: double.tryParse(ratingCtrl.text) ?? 0.0,
                firstAirDate: dateCtrl.text,
              );
              await context.read<MovieProvider>().updateSeriesFull(updated);
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteMovie(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Tem certeza que deseja remover este filme?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<MovieProvider>().deleteMovie(id);
    }
  }

  void _deleteSeries(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Tem certeza que deseja remover esta série?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<MovieProvider>().deleteSeries(id);
    }
  }
}

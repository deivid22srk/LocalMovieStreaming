import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/movie_provider.dart';
import '../../models/movie_models.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _isSearchingSeries = false;

  void _search() async {
    setState(() => _isLoading = true);
    final provider = context.read<MovieProvider>();
    try {
      if (_isSearchingSeries) {
        _searchResults = await provider.searchSeries(_searchController.text);
      } else {
        _searchResults = await provider.searchMovies(_searchController.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao buscar: Verifique sua chave API nas configurações.')),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showAddDialog(dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adicionar ${item is Movie ? item.title : item['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isSearchingSeries)
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL do Filme'),
              )
            else
              const Text('Todas as temporadas e episódios serão coletados. As URLs deverão ser editadas na tela de detalhes.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final provider = context.read<MovieProvider>();
              if (!_isSearchingSeries) {
                await provider.addMovie(Movie(
                  title: item.title,
                  overview: item.overview,
                  posterPath: item.posterPath,
                  backdropPath: item.backdropPath,
                  videoUrl: _urlController.text,
                  voteAverage: item.voteAverage,
                  releaseDate: item.releaseDate,
                ));
              } else {
                setState(() => _isLoading = true);
                Navigator.pop(context);
                await provider.addSeriesWithMetadata(item);
                setState(() => _isLoading = false);
              }
              if (mounted) {
                if (!_isSearchingSeries) Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Filme/Série'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar na API TMDB...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Filmes'),
                Switch(
                  value: _isSearchingSeries,
                  onChanged: (v) => setState(() => _isSearchingSeries = v),
                ),
                const Text('Séries'),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    final String title = item is Movie ? item.title : item['name'];
                    final String posterPath = item is Movie
                        ? item.posterPath
                        : (item['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${item['poster_path']}' : '');
                    final String sub = item is Movie ? item.releaseDate : (item['first_air_date'] ?? '');

                    return ListTile(
                      leading: CachedNetworkImage(
                        imageUrl: posterPath,
                        width: 50,
                        placeholder: (context, url) => Container(color: Colors.grey),
                        errorWidget: (context, url, error) => const Icon(Icons.movie),
                      ),
                      title: Text(title),
                      subtitle: Text(sub),
                      onTap: () => _showAddDialog(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

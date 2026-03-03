import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/movie_provider.dart';
import '../../models/movie_models.dart';
import '../widgets/app_image.dart';
import '../../services/telegram_service.dart';
import 'telegram_selector_screen.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  // Manual form controllers
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _overviewCtrl = TextEditingController();
  final TextEditingController _posterCtrl = TextEditingController();
  final TextEditingController _backdropCtrl = TextEditingController();
  final TextEditingController _manualUrlCtrl = TextEditingController();
  final TextEditingController _webUrlCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();

  // Telegram Capture data
  String? _tgFileId;
  String? _tgFileName;
  int? _tgFileSize;
  int? _tgAccessHash;
  List<int>? _tgFileReference;

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _isSearchingSeries = false;
  bool _manualIsSeries = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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

  Future<void> _pickImage(TextEditingController controller) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      controller.text = result.files.single.path!;
    }
  }

  void _addManual() async {
    if (_titleCtrl.text.isEmpty) return;

    final provider = context.read<MovieProvider>();
    setState(() => _isLoading = true);

    if (_manualIsSeries) {
      await provider.addSeriesManual(Series(
        title: _titleCtrl.text,
        overview: _overviewCtrl.text,
        posterPath: _posterCtrl.text,
        backdropPath: _backdropCtrl.text,
        voteAverage: 0.0,
        firstAirDate: _dateCtrl.text,
        category: _categoryCtrl.text,
      ));
    } else {
      await provider.addMovie(Movie(
        title: _titleCtrl.text,
        overview: _overviewCtrl.text,
        posterPath: _posterCtrl.text,
        backdropPath: _backdropCtrl.text,
        videoUrl: _manualUrlCtrl.text,
        webPlayerUrl: _webUrlCtrl.text,
        voteAverage: 0.0,
        releaseDate: _dateCtrl.text,
        telegramFileId: _tgFileId,
        telegramFileName: _tgFileName,
        telegramFileSize: _tgFileSize,
        telegramAccessHash: _tgAccessHash?.toString(),
        category: _categoryCtrl.text,
        isTelegram: _tgFileId != null,
      ));
    }

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  void _captureTelegram() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const TelegramSelectorScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _tgFileId = result['id'];
        _tgFileName = result['fileName'];
        _tgFileSize = result['size'];
        _tgAccessHash = result['accessHash'];
        _tgFileReference = result['fileReference'];
        _manualUrlCtrl.text = 'TELEGRAM: ${_tgFileName}';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vídeo do Telegram selecionado!')));
    }
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
        title: const Text('Adicionar Novo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'BUSCAR API'),
            Tab(text: 'MANUAL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApiSearchTab(),
          _buildManualTab(),
        ],
      ),
    );
  }

  Widget _buildApiSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar no TMDB...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
            ),
            onSubmitted: (_) => _search(),
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

                  return ListTile(
                    leading: AppImage(path: posterPath, width: 50),
                    title: Text(title),
                    onTap: () => _showAddDialog(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Filme'),
              Switch(
                value: _manualIsSeries,
                onChanged: (v) => setState(() => _manualIsSeries = v),
              ),
              const Text('Série'),
            ],
          ),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
          TextField(controller: _overviewCtrl, decoration: const InputDecoration(labelText: 'Sinopse'), maxLines: 3),
          TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Data de Lançamento (Ex: 2024-01-01)')),
          TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: 'Categoria')),
          if (!_manualIsSeries) ...[
            TextField(controller: _manualUrlCtrl, decoration: const InputDecoration(labelText: 'URL do Vídeo')),
            TextField(controller: _webUrlCtrl, decoration: const InputDecoration(labelText: 'URL do Player Web (Opcional)')),
          ],
          const SizedBox(height: 20),
          if (!_manualIsSeries)
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              onPressed: _captureTelegram,
              label: const Text('CAPTURAR DO TELEGRAM'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
          const SizedBox(height: 20),
          _buildImagePickerRow('Capa (Poster)', _posterCtrl),
          const SizedBox(height: 10),
          _buildImagePickerRow('Banner (Backdrop)', _backdropCtrl),
          const SizedBox(height: 30),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: _addManual,
              child: const Text('SALVAR MANUALMENTE'),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePickerRow(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Link ou caminho do arquivo'))),
            IconButton(icon: const Icon(Icons.file_open), onPressed: () => _pickImage(controller)),
          ],
        ),
      ],
    );
  }
}

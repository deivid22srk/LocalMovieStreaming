import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/movie_provider.dart';
import '../../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = context.read<MovieProvider>().apiKey;
  }

  void _export() async {
    final path = await _storageService.exportData();
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dados exportados com sucesso para: $path')));
    }
  }

  void _import() async {
    final success = await _storageService.importData();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados importados com sucesso!')));
      context.read<MovieProvider>().fetchMovies();
      context.read<MovieProvider>().fetchSeriesList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('API TMDB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              hintText: 'Insira sua chave API do TMDB...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  context.read<MovieProvider>().apiKey = _apiKeyController.text;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave API salva!')));
                },
              ),
            ),
            onSubmitted: (v) => context.read<MovieProvider>().apiKey = v,
          ),
          const SizedBox(height: 10),
          const Text(
            'Obtenha uma chave gratuita em: themoviedb.org',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 30),
          const Text('Backup e Sincronização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Exportar dados (ZIP)'),
            subtitle: const Text('Gera um backup de toda sua biblioteca e progresso.'),
            onTap: _export,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Importar dados (ZIP)'),
            subtitle: const Text('Restaura dados de um backup anterior.'),
            onTap: _import,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 40),
          const Center(
             child: Text('Desenvolvido para Local Movie Player', style: TextStyle(fontSize: 12, color: Colors.white24)),
          ),
        ],
      ),
    );
  }
}

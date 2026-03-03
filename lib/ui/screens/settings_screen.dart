import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/movie_provider.dart';
import '../../services/storage_service.dart';
import '../../services/telegram_service.dart';
import 'library_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _tgTokenCtrl = TextEditingController();
  final TextEditingController _tgUsernameCtrl = TextEditingController();
  final TextEditingController _tgIdCtrl = TextEditingController();
  final TextEditingController _tgHashCtrl = TextEditingController();
  final TextEditingController _tgPhoneCtrl = TextEditingController();
  final TextEditingController _tgGroupCtrl = TextEditingController();

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final p = context.read<MovieProvider>();
    _apiKeyController.text = p.apiKey;
    _tgTokenCtrl.text = p.tgBotToken;
    _tgUsernameCtrl.text = p.tgBotUsername;
    _tgIdCtrl.text = p.tgApiId;
    _tgHashCtrl.text = p.tgApiHash;
    _tgPhoneCtrl.text = p.tgPhoneNumber;
    _tgGroupCtrl.text = p.tgGroupId;
  }

  void _export() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportando dados... Aguarde.')));
    final result = await _storageService.exportData();
    if (result != null) {
       if (result.contains('Error') || result.contains('failed')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação: $result'), backgroundColor: Colors.red));
       } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup iniciado via compartilhamento.'), backgroundColor: Colors.green));
       }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação cancelada.')));
    }
  }

  void _import() async {
    final success = await _storageService.importData();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados importados com sucesso!'), backgroundColor: Colors.green));
      context.read<MovieProvider>().fetchMovies();
      context.read<MovieProvider>().fetchSeriesList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha na importação ou cancelada.'), backgroundColor: Colors.red));
    }
  }

  void _backupToTelegram() async {
     final provider = context.read<MovieProvider>();
     if (provider.tgBotToken.isEmpty || provider.tgGroupId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure o Bot Token e Group ID primeiro.')));
        return;
     }
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando backup para o Telegram...')));
     final result = await _storageService.backupToTelegram(provider.tgBotToken, provider.tgGroupId);
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Erro desconhecido')));
  }

  void _restoreFromTelegram() async {
     final provider = context.read<MovieProvider>();
     if (provider.tgBotToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure o Bot Token primeiro.')));
        return;
     }
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando backup no Telegram...')));
     final result = await _storageService.restoreFromTelegram(provider.tgBotToken);
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Erro desconhecido')));
  }

  void _startLoginFlow() async {
     final provider = context.read<MovieProvider>();
     if (provider.tgPhoneNumber.isEmpty || provider.tgApiId.isEmpty || provider.tgApiHash.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos de API e Telefone antes de logar.')));
        return;
     }

     final messenger = ScaffoldMessenger.of(context);

     try {
        await TelegramService.initClient(
          apiId: provider.tgApiId,
          apiHash: provider.tgApiHash,
          dbPath: 'telegram_session',
        );

        await TelegramService.setPhoneNumber(provider.tgPhoneNumber);

        if (mounted) _showCodeDialog();
     } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Erro no login: $e'), backgroundColor: Colors.red));
     }
  }

  void _showCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Código do Telegram'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(hintText: 'Digite o código recebido'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<MovieProvider>();
              try {
                await TelegramService.checkCode(codeCtrl.text);
                provider.tgIsLoggedIn = true;
                if (mounted) {
                   Navigator.pop(context);
                   messenger.showSnackBar(const SnackBar(content: Text('Login realizado com sucesso!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Erro ao verificar código: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('VERIFICAR'),
          ),
        ],
      ),
    );
  }

  void _saveTelegram() async {
    await context.read<MovieProvider>().saveTelegramConfig(
      botToken: _tgTokenCtrl.text,
      botUsername: _tgUsernameCtrl.text,
      apiId: _tgIdCtrl.text,
      apiHash: _tgHashCtrl.text,
      phoneNumber: _tgPhoneCtrl.text,
      groupId: _tgGroupCtrl.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações do Telegram salvas!')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Biblioteca', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Gerenciar Biblioteca'),
            subtitle: const Text('Edite ou remova filmes e séries já adicionados.'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryManagementScreen())),
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Restaurar via Telegram'),
            subtitle: const Text('Busca o backup mais recente no seu grupo do Telegram.'),
            onTap: _restoreFromTelegram,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('Backup via Telegram'),
            subtitle: const Text('Envia o arquivo ZIP de backup para o seu grupo do Telegram.'),
            onTap: _backupToTelegram,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 30),
          const Text('Player de Vídeo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Utilizar VLC Nativo (Kotlin)'),
            subtitle: const Text('Se ativado, utiliza o VLC via ponte nativa para maior performance em streams locais.'),
            value: provider.useNativePlayer,
            onChanged: (v) => provider.useNativePlayer = v,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 30),
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
          const Text('Telegram Bot & Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                TextField(controller: _tgTokenCtrl, decoration: const InputDecoration(labelText: 'Bot Token')),
                TextField(controller: _tgUsernameCtrl, decoration: const InputDecoration(labelText: 'Bot Username')),
                TextField(controller: _tgIdCtrl, decoration: const InputDecoration(labelText: 'API ID')),
                TextField(controller: _tgHashCtrl, decoration: const InputDecoration(labelText: 'API Hash')),
                TextField(controller: _tgPhoneCtrl, decoration: const InputDecoration(labelText: 'Número do Telefone (com DDI)')),
                TextField(controller: _tgGroupCtrl, decoration: const InputDecoration(labelText: 'Group ID')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveTelegram,
                  child: const Text('SALVAR CONFIGURAÇÕES TELEGRAM'),
                ),
                const SizedBox(height: 10),
                provider.tgIsLoggedIn
                  ? const Text('Status: LOGADO', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: _startLoginFlow,
                      child: const Text('FAZER LOGIN CLIENTE'),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text('Backup e Sincronização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Exportar dados (ZIP)'),
            subtitle: const Text('Gera um backup de toda sua biblioteca, progresso e imagens.'),
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

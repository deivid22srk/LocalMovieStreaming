import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/movie_provider.dart';
import '../../services/telegram_service.dart';
import 'home_screen.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _apiIdCtrl = TextEditingController();
  final TextEditingController _apiHashCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _botTokenCtrl = TextEditingController();
  final TextEditingController _botUserCtrl = TextEditingController();
  final TextEditingController _groupIdCtrl = TextEditingController();

  bool _isLoading = false;
  int _currentPage = 0;

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void _startLogin() async {
    if (_apiIdCtrl.text.isEmpty || _apiHashCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await TelegramService.initClient(
        apiId: _apiIdCtrl.text,
        apiHash: _apiHashCtrl.text,
        dbPath: 'telegram_session',
      );
      await TelegramService.setPhoneNumber(_phoneCtrl.text);
      _nextPage();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifyCode() async {
    if (_codeCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await TelegramService.checkCode(_codeCtrl.text);
      _nextPage();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código inválido: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _finishSetup() async {
    final provider = context.read<MovieProvider>();
    await provider.saveTelegramConfig(
      botToken: _botTokenCtrl.text,
      botUsername: _botUserCtrl.text,
      apiId: _apiIdCtrl.text,
      apiHash: _apiHashCtrl.text,
      phoneNumber: _phoneCtrl.text,
      groupId: _groupIdCtrl.text,
    );
    provider.tgIsLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false);

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            _buildWelcomePage(),
            _buildApiPage(),
            _buildPhonePage(),
            _buildCodePage(),
            _buildBotPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter, size: 100, color: Color(0xFF7E3FF2)),
          const SizedBox(height: 30),
          const Text('Bem-vindo ao Local Movie Player',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          const Text('Vamos configurar sua integração com o Telegram para streaming de alta performance.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
            child: const Text('COMEÇAR CONFIGURAÇÃO'),
          ),
        ],
      ),
    );
  }

  Widget _buildApiPage() {
    return _buildStepPage(
      title: 'Credenciais da API',
      description: 'Obtenha em my.telegram.org',
      children: [
        TextField(controller: _apiIdCtrl, decoration: const InputDecoration(labelText: 'API ID')),
        TextField(controller: _apiHashCtrl, decoration: const InputDecoration(labelText: 'API Hash')),
      ],
      onNext: _nextPage,
    );
  }

  Widget _buildPhonePage() {
    return _buildStepPage(
      title: 'Seu Telefone',
      description: 'Insira o número com DDI (Ex: +55...)',
      children: [
        TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Número do Telefone'), keyboardType: TextInputType.phone),
      ],
      onNext: _startLogin,
      loading: _isLoading,
    );
  }

  Widget _buildCodePage() {
    return _buildStepPage(
      title: 'Verificação',
      description: 'Digite o código que você recebeu no Telegram',
      children: [
        TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Código'), keyboardType: TextInputType.number),
      ],
      onNext: _verifyCode,
      loading: _isLoading,
    );
  }

  Widget _buildBotPage() {
    return _buildStepPage(
      title: 'Bot & Grupo',
      description: 'Configure o bot e o ID do grupo para capturas',
      children: [
        TextField(controller: _botTokenCtrl, decoration: const InputDecoration(labelText: 'Bot Token')),
        TextField(controller: _botUserCtrl, decoration: const InputDecoration(labelText: 'Bot Username')),
        TextField(controller: _groupIdCtrl, decoration: const InputDecoration(labelText: 'Group ID')),
      ],
      onNext: _finishSetup,
      nextLabel: 'CONCLUIR',
    );
  }

  Widget _buildStepPage({
    required String title,
    required String description,
    required List<Widget> children,
    required VoidCallback onNext,
    String nextLabel = 'PRÓXIMO',
    bool loading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 30),
          ...children,
          const Spacer(),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
              child: Text(nextLabel),
            ),
        ],
      ),
    );
  }
}

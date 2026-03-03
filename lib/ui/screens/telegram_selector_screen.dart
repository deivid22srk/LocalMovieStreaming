import 'package:flutter/material.dart';
import '../../services/telegram_service.dart';

class TelegramSelectorScreen extends StatefulWidget {
  const TelegramSelectorScreen({super.key});

  @override
  State<TelegramSelectorScreen> createState() => _TelegramSelectorScreenState();
}

class _TelegramSelectorScreenState extends State<TelegramSelectorScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _videos = [];
  Map<String, dynamic>? _selectedChat;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await TelegramService.getChats();
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar chats: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVideos(Map<String, dynamic> chat) async {
    setState(() {
      _selectedChat = chat;
      _isLoading = true;
    });
    try {
      final videos = await TelegramService.getVideosFromChat(chat['id'], chat['accessHash']);
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar vídeos: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedChat == null ? 'Selecionar Chat' : 'Selecionar Vídeo'),
        leading: _selectedChat != null
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedChat = null))
          : null,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _selectedChat == null ? _buildChatList() : _buildVideoList(),
    );
  }

  Widget _buildChatList() {
    if (_chats.isEmpty) return const Center(child: Text('Nenhum chat encontrado.'));

    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.group)),
          title: Text(chat['title']),
          subtitle: Text(chat['type']),
          onTap: () => _loadVideos(chat),
        );
      },
    );
  }

  Widget _buildVideoList() {
    if (_videos.isEmpty) return const Center(child: Text('Nenhum vídeo encontrado neste chat.'));

    return ListView.builder(
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return ListTile(
          leading: const Icon(Icons.movie, color: Colors.blue),
          title: Text(video['fileName']),
          subtitle: video['caption'] != null && video['caption'].isNotEmpty
            ? Text(video['caption'], maxLines: 2, overflow: TextOverflow.ellipsis)
            : Text('${(video['size'] / (1024 * 1024)).toStringAsFixed(2)} MB'),
          onTap: () => Navigator.pop(context, video),
        );
      },
    );
  }
}

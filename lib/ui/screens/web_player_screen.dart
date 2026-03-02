import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebPlayerScreen({super.key, required this.url, required this.title});

  @override
  State<WebPlayerScreen> createState() => _WebPlayerScreenState();
}

class _WebPlayerScreenState extends State<WebPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _errorMessage = "Erro ao carregar: ${error.description}";
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.purple)),
          if (_errorMessage != null)
             Center(
               child: Container(
                 padding: const EdgeInsets.all(20),
                 color: Colors.black87,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.error_outline, color: Colors.red, size: 60),
                     const SizedBox(height: 10),
                     Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text('VOLTAR'))
                   ],
                 ),
               ),
             ),
        ],
      ),
    );
  }
}

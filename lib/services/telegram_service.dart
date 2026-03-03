import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:telegram_client/telegram_client.dart';

class TelegramService {
  final String botToken;

  TelegramService(this.botToken);

  Future<Map<String, dynamic>?> waitForNextVideo() async {
    int lastUpdateId = 0;

    // Get last update ID first to avoid capturing old messages
    try {
      final initialResponse = await http.get(Uri.parse('https://api.telegram.org/bot$botToken/getUpdates?offset=-1'));
      if (initialResponse.statusCode == 200) {
        final data = json.decode(initialResponse.body);
        if (data['ok'] == true && (data['result'] as List).isNotEmpty) {
          lastUpdateId = data['result'][0]['update_id'];
        }
      }
    } catch (e) {
      print('Error getting initial Telegram update: $e');
    }

    final startTime = DateTime.now();
    // Poll for 2 minutes
    while (DateTime.now().difference(startTime).inMinutes < 2) {
      try {
        final response = await http.get(Uri.parse('https://api.telegram.org/bot$botToken/getUpdates?offset=${lastUpdateId + 1}&timeout=30'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['ok'] == true) {
            final List results = data['result'];
            for (var update in results) {
              lastUpdateId = update['update_id'];
              final message = update['message'];
              if (message != null) {
                final video = message['video'] ?? message['document'];
                if (video != null && (message['video'] != null || _isFileTypeVideo(video['mime_type']))) {
                  return {
                    'file_id': video['file_id'],
                    'file_name': video['file_name'] ?? 'video_${video['file_id']}.mp4',
                    'file_size': video['file_size'],
                    'mime_type': video['mime_type'],
                    // For client API playback
                    'access_hash': '', // Will be resolved by client API if needed
                    'peer_id': message['from']['id'].toString(),
                  };
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error polling Telegram: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  bool _isFileTypeVideo(String? mime) {
    if (mime == null) return false;
    return mime.startsWith('video/') || mime == 'application/x-mpegURL' || mime == 'application/vnd.apple.mpegurl';
  }

  // Local Proxy Server for Streaming
  static HttpServer? _server;
  static const int proxyPort = 8080;

  static TelegramClient? _client;

  static Future<void> initClient(String apiId, String apiHash) async {
    if (_client != null) return;
    _client = TelegramClient();
    // In a real scenario, we would need to call ensureInitialized or similar if the library requires it.
  }

  static Future<void> startProxy() async {
    if (_server != null) return;

    final router = Router();

    router.get('/stream/<fileId>', (Request request, String fileId) async {
      final range = request.headers['range'];
      print('Proxy Request: fileId=$fileId, range=$range');

      // TODO: Use MTProto client to fetch chunks from Telegram
      // For now, this is a placeholder for the actual streaming logic
      // In a real implementation, we would use the MTProto library to request
      // specific offsets and return them as a streamed response.

      return Response.ok('Streaming data for $fileId is not yet linked to MTProto Client.',
          headers: {'content-type': 'video/mp4'});
    });

    try {
      _server = await io.serve(router, InternetAddress.loopbackIPv4, proxyPort);
      print('Telegram Proxy Server running on port ${_server!.port}');
    } catch (e) {
      print('Error starting proxy server: $e');
    }
  }

  static Future<void> stopProxy() async {
    await _server?.close(force: true);
    _server = null;
  }

  static String getProxyUrl(String fileId) {
    return 'http://localhost:$proxyPort/stream/$fileId';
  }
}

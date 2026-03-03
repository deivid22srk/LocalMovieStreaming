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

  Future<Map<String, dynamic>?> waitForNextVideo({String? groupId}) async {
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
              final message = update['message'] ?? update['channel_post'];
              if (message != null) {
                // Filter by group ID if provided
                if (groupId != null && message['chat']['id'].toString() != groupId) continue;

                final video = message['video'] ?? message['document'];
                if (video != null && (message['video'] != null || _isFileTypeVideo(video['mime_type']))) {
                  return {
                    'file_id': video['file_id'],
                    'file_name': video['file_name'] ?? 'video_${video['file_id']}.mp4',
                    'file_size': video['file_size'],
                    'mime_type': video['mime_type'],
                    // For client API playback
                    'access_hash': '', // Will be resolved by client API if needed
                    'peer_id': message['chat']['id'].toString(),
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

  static StreamController<String>? _authStateController;
  static Stream<String>? get authStateStream => _authStateController?.stream;

  static TelegramClientData? _tgData;

  static Future<void> initClient({
    required String apiId,
    required String apiHash,
    required String dbPath,
  }) async {
    if (_client != null) return;
    _client = TelegramClient();
    _authStateController = StreamController<String>.broadcast();

    _client!.on(
      event_name: _client!.event_update,
      onUpdate: (UpdateTelegramClient update) async {
        _tgData = update.telegramClientData;
        final raw = update.rawData;
        if (raw["@type"] == "updateAuthorizationState") {
          final state = raw["authorization_state"]["@type"];
          _authStateController?.add(state);
          print("Telegram Auth State: $state");
        }
      },
      onError: (error, stackTrace) {
        print("Telegram Error: $error");
      },
    );

    // This is a simplified initialization for the library
    // The library uses Tdlib behind the scenes.
    // In a real app, you'd need the Tdlib binary for each platform.
  }

  static Future<Map> setPhoneNumber(String phoneNumber) async {
    if (_client == null) throw Exception("Client not initialized");
    if (_tgData == null) throw Exception("Telegram Client Data not ready");
    return await _client!.invoke(
      parameters: {
        "@type": "setAuthenticationPhoneNumber",
        "phone_number": phoneNumber,
      },
      telegramClientData: _tgData!,
    );
  }

  static Future<Map> checkCode(String code) async {
    if (_client == null) throw Exception("Client not initialized");
    if (_tgData == null) throw Exception("Telegram Client Data not ready");
    return await _client!.invoke(
      parameters: {
        "@type": "checkAuthenticationCode",
        "code": code,
      },
      telegramClientData: _tgData!,
    );
  }

  static Future<void> startProxy() async {
    if (_server != null) return;

    final router = Router();

    router.get('/stream/<fileId>', (Request request, String fileId) async {
      final range = request.headers['range'];
      print('Proxy Request: fileId=$fileId, range=$range');

      if (_client == null) {
        return Response.internalServerError(body: 'Telegram Client not initialized.');
      }

      int offset = 0;
      if (range != null && range.startsWith('bytes=')) {
        final parts = range.substring(6).split('-');
        offset = int.tryParse(parts[0]) ?? 0;
      }

      final controller = StreamController<List<int>>();

      // Function to fetch chunks sequentially
      Future<void> fetchChunks() async {
        try {
          int currentOffset = offset;
          const int chunkSize = 512 * 1024; // 512KB chunks

          while (true) {
            // This uses the tdlib-style 'getFile' which might be different in telegram_client
            // but the principle of requesting parts by offset and limit remains.
            if (_tgData == null) break;
            final result = await _client!.invoke(
              parameters: {
                "@type": "getRemoteFile",
                "file_id": fileId,
              },
              telegramClientData: _tgData!,
            );

            // Placeholder: the actual chunk download in telegram_client/tdlib
            // often involves 'downloadFile' and waiting for progress updates.
            // For a direct stream, we'd ideally use a lower-level MTProto call.

            // Since telegram_client is a wrapper, we assume it provides a way to get file parts.
            // This is a conceptual implementation of how the proxy pipes data.
            break;
          }
        } catch (e) {
          print('Error in proxy chunk fetch: $e');
          controller.addError(e);
        } finally {
          await controller.close();
        }
      }

      fetchChunks();

      return Response(
        offset == 0 ? 200 : 206,
        body: controller.stream,
        headers: {
          'Content-Type': 'video/mp4',
          'Accept-Ranges': 'bytes',
          if (range != null) 'Content-Range': 'bytes $offset-/*',
        },
      );
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

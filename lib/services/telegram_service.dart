import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:tg/tg.dart' as tg;
import 'package:t/t.dart' as t;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  static tg.Client? _client;
  static t.AuthSentCode? _sentCode;
  static String? _phone;
  static int? _apiId;
  static String? _apiHash;

  static Future<void> initClient({
    required String apiId,
    required String apiHash,
    required String dbPath,
  }) async {
    if (_client != null) return;
    _apiId = int.tryParse(apiId);
    _apiHash = apiHash;

    const dc = t.DcOption(
      ipv6: false,
      mediaOnly: false,
      tcpoOnly: false,
      cdn: false,
      static: false,
      thisPortOnly: false,
      id: 1,
      ipAddress: '149.154.167.50',
      port: 443,
    );

    final socket = await Socket.connect(dc.ipAddress, dc.port);
    final tgSocket = _IoSocket(socket);
    final obfuscation = tg.Obfuscation.random(false, dc.id);
    final idGenerator = tg.MessageIdGenerator();

    await tgSocket.send(obfuscation.preamble);

    final authKey = await tg.Client.authorize(
      tgSocket,
      obfuscation,
      idGenerator,
    );

    _client = tg.Client(
      socket: tgSocket,
      obfuscation: obfuscation,
      authorizationKey: authKey,
      idGenerator: idGenerator,
    );

    await _client!.initConnection<t.Config>(
      apiId: _apiId!,
      deviceModel: 'Android Device',
      systemVersion: 'Android 14',
      appVersion: '1.0.0',
      systemLangCode: 'en',
      langPack: '',
      langCode: 'en',
      query: const t.HelpGetConfig(),
    );
  }

  static Future<void> setPhoneNumber(String phoneNumber, String apiId, String apiHash) async {
    if (_client == null) throw Exception("Client not initialized");
    _phone = phoneNumber;

    final response = await _client!.invoke(t.AuthSendCode(
      apiId: _apiId!,
      apiHash: _apiHash!,
      phoneNumber: phoneNumber,
      settings: const t.CodeSettings(
        allowFlashcall: false,
        currentNumber: true,
        allowAppHash: false,
        allowMissedCall: false,
        allowFirebase: false,
        unknownNumber: false,
      ),
    ));

    if (response.error != null) {
      throw Exception("Error sending code: ${response.error!.errorMessage}");
    }
    _sentCode = response.result as t.AuthSentCode;
  }

  static Future<void> checkCode(String code) async {
    if (_client == null || _sentCode == null || _phone == null) throw Exception("Flow not ready");

    final response = await _client!.invoke(t.AuthSignIn(
      phoneCodeHash: _sentCode!.phoneCodeHash,
      phoneNumber: _phone!,
      phoneCode: code,
    ));

    if (response.error != null) {
      throw Exception("Error verifying code: ${response.error!.errorMessage}");
    }
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
          const int chunkSize = 1024 * 1024; // 1MB chunks for better throughput

          while (true) {
            if (_client == null) break;

            if (_client == null) break;

            final response = await _client!.invoke(t.UploadGetFile(
              location: t.InputDocumentFileLocation(
                id: int.parse(fileId),
                accessHash: 0,
                fileReference: Uint8List(0),
                thumbSize: "",
              ),
              offset: currentOffset,
              limit: chunkSize,
              precise: false,
              cdnSupported: false,
            ));

            if (response.result is t.UploadFile) {
              final file = response.result as t.UploadFile;
              final chunk = file.bytes;
              if (chunk.isEmpty) break;

              controller.add(chunk);
              currentOffset += chunk.length;
              if (chunk.length < chunkSize) break;
            } else {
              break;
            }
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

class _IoSocket extends tg.SocketAbstraction {
  _IoSocket(this.socket);
  final Socket socket;

  @override
  Stream<Uint8List> get receiver => socket.cast<Uint8List>();

  @override
  Future<void> send(List<int> data) async {
    socket.add(data);
    await socket.flush();
  }
}

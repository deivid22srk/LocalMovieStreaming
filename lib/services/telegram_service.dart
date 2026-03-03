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

  bool _isFileTypeVideo(String? mime) {
    if (mime == null) return false;
    return mime.startsWith('video/') || mime == 'application/x-mpegURL' || mime == 'application/vnd.apple.mpegurl';
  }

  static HttpServer? _server;
  static const int proxyPort = 8080;

  static tg.Client? _client;
  static t.AuthSentCode? _sentCode;
  static String? _phone;
  static int? _apiId;
  static String? _apiHash;
  static int _currentDcId = 1;

  static final Map<int, String> _dcIps = {
    1: '149.154.167.50',
    2: '149.154.167.51',
    3: '149.154.175.100',
    4: '149.154.167.91',
    5: '149.154.167.92',
  };

  static Future<void> initClient({
    required String apiId,
    required String apiHash,
    required String dbPath,
    int dcId = 1,
  }) async {
    _apiId = int.tryParse(apiId);
    _apiHash = apiHash;
    _currentDcId = dcId;

    final ip = _dcIps[dcId] ?? _dcIps[1]!;
    print("Connecting to Telegram DC $dcId ($ip)...");

    try {
      final socket = await Socket.connect(ip, 443).timeout(const Duration(seconds: 10));
      final tgSocket = _IoSocket(socket);
      final obfuscation = tg.Obfuscation.random(false, dcId);
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
    } catch (e) {
       print("Init error DC $dcId: $e");
       _client = null;
       throw Exception("Failed to initialize Telegram client on DC $dcId: $e");
    }
  }

  static Future<void> setPhoneNumber(String phoneNumber, String apiId, String apiHash) async {
    if (_client == null) await initClient(apiId: apiId, apiHash: apiHash, dbPath: 'telegram_session');
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
      final err = response.error!.errorMessage;
      if (err.startsWith('PHONE_MIGRATE_')) {
         final nextDc = int.parse(err.split('_').last);
         print("Phone Migration requested to DC $nextDc");
         _client = null; // Reset current client
         await initClient(apiId: apiId, apiHash: apiHash, dbPath: 'telegram_session', dcId: nextDc);
         return setPhoneNumber(phoneNumber, apiId, apiHash); // Retry on new DC
      }
      throw Exception("Error sending code: $err");
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

  static Future<List<Map<String, dynamic>>> getChats() async {
    if (_client == null) throw Exception("Client not initialized");

    final response = await _client!.invoke(t.MessagesGetDialogs(
      offsetDate: DateTime.fromMillisecondsSinceEpoch(0),
      offsetId: 0,
      offsetPeer: const t.InputPeerEmpty(),
      limit: 100,
      hash: 0,
      excludePinned: false,
    ));

    final List<Map<String, dynamic>> chats = [];
    final res = response.result;
    List<t.ChatBase> tChats = [];
    if (res is t.MessagesDialogs) tChats = res.chats;
    else if (res is t.MessagesDialogsSlice) tChats = res.chats;

    for (var chat in tChats) {
      String title = "Unknown";
      String id = "";
      int? accessHash;

      if (chat is t.Chat) {
        title = chat.title;
        id = chat.id.toString();
      } else if (chat is t.Channel) {
        title = chat.title;
        id = chat.id.toString();
        accessHash = chat.accessHash;
      }

      if (id.isNotEmpty) {
        chats.add({
          'id': id,
          'title': title,
          'accessHash': accessHash,
          'type': chat.runtimeType.toString(),
        });
      }
    }
    return chats;
  }

  static Future<List<Map<String, dynamic>>> getVideosFromChat(String chatId, int? accessHash) async {
    if (_client == null) throw Exception("Client not initialized");

    t.InputPeerBase peer;
    final int id = int.parse(chatId);
    if (accessHash != null) {
       peer = t.InputPeerChannel(channelId: id, accessHash: accessHash);
    } else {
       peer = t.InputPeerChat(chatId: id);
    }

    final response = await _client!.invoke(t.MessagesSearch(
      peer: peer,
      q: "",
      filter: const t.InputMessagesFilterVideo(),
      minDate: DateTime.fromMillisecondsSinceEpoch(0),
      maxDate: DateTime.fromMillisecondsSinceEpoch(0),
      offsetId: 0,
      addOffset: 0,
      limit: 50,
      maxId: 0,
      minId: 0,
      hash: 0,
    ));

    final List<Map<String, dynamic>> videos = [];
    final res = response.result;
    List<t.MessageBase> msgs = [];
    if (res is t.MessagesMessages) msgs = res.messages;
    else if (res is t.MessagesMessagesSlice) msgs = res.messages;
    else if (res is t.MessagesChannelMessages) msgs = res.messages;

    for (var msg in msgs) {
      if (msg is t.Message) {
        final media = msg.media;
        if (media is t.MessageMediaDocument) {
          final doc = media.document;
          if (doc is t.Document) {
            videos.add({
              'id': doc.id.toString(),
              'accessHash': doc.accessHash,
              'fileReference': doc.fileReference,
              'size': doc.size,
              'fileName': _getFileNameFromDoc(doc),
              'caption': msg.message,
            });
          }
        }
      }
    }
    return videos;
  }

  static String _getFileNameFromDoc(t.Document doc) {
     for (var attr in doc.attributes) {
        if (attr is t.DocumentAttributeFilename) {
           return attr.fileName;
        }
     }
     return "video_${doc.id}.mp4";
  }

  static Future<void> startProxy() async {
    if (_server != null) return;

    final router = Router();

    router.get('/stream/<fileId>', (Request request, String fileId) async {
      final range = request.headers['range'];
      final accessHashStr = request.url.queryParameters['accessHash'];
      print('Proxy Request: fileId=$fileId, range=$range, accessHash=$accessHashStr');

      if (_client == null) {
        return Response.internalServerError(body: 'Telegram Client not initialized.');
      }

      int offset = 0;
      if (range != null && range.startsWith('bytes=')) {
        final parts = range.substring(6).split('-');
        offset = int.tryParse(parts[0]) ?? 0;
      }

      final controller = StreamController<List<int>>();

      Future<void> fetchChunks() async {
        try {
          int currentOffset = offset;
          const int chunkSize = 1024 * 1024;

          while (true) {
            if (_client == null) break;

            final response = await _client!.invoke(t.UploadGetFile(
              location: t.InputDocumentFileLocation(
                id: int.parse(fileId),
                accessHash: int.tryParse(accessHashStr ?? '0') ?? 0,
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

  static String getProxyUrl(String fileId, {String? accessHash}) {
    String url = 'http://localhost:$proxyPort/stream/$fileId';
    if (accessHash != null) url += '?accessHash=$accessHash';
    return url;
  }
}

class _IoSocket extends tg.SocketAbstraction {
  _IoSocket(this.socket) : receiver = socket.cast<Uint8List>().asBroadcastStream();
  final Socket socket;

  @override
  final Stream<Uint8List> receiver;

  @override
  Future<void> send(List<int> data) async {
    socket.add(data);
    await socket.flush();
  }
}

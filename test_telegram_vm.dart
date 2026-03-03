
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:t/t.dart' as t;
import 'package:tg/tg.dart' as tg;

class IoSocket extends tg.SocketAbstraction {
  IoSocket(this.socket) : receiver = socket.cast<Uint8List>().asBroadcastStream();
  final Socket socket;

  @override
  final Stream<Uint8List> receiver;

  @override
  Future<void> send(List<int> data) async {
    socket.add(data);
    await socket.flush();
  }
}

void main() async {
  print('Testing Telegram connection (Dart VM)...');

  final apiId = 20690169;
  final apiHash = '4222211cf4f8180a88b2b66ffa5420b0';
  final phoneNumber = '5587996156854';

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

  try {
    print('Connecting to $dc...');
    final socket = await Socket.connect(dc.ipAddress, dc.port).timeout(const Duration(seconds: 10));
    final tgSocket = IoSocket(socket);
    final obfuscation = tg.Obfuscation.random(false, dc.id);
    final idGenerator = tg.MessageIdGenerator();

    await tgSocket.send(obfuscation.preamble);

    print('Authorizing...');
    final authKey = await tg.Client.authorize(
      tgSocket,
      obfuscation,
      idGenerator,
    );

    print('Creating Client...');
    final client = tg.Client(
      socket: tgSocket,
      obfuscation: obfuscation,
      authorizationKey: authKey,
      idGenerator: idGenerator,
    );

    print('Initializing Connection...');
    await client.initConnection<t.Config>(
      apiId: apiId,
      deviceModel: 'Test Server',
      systemVersion: 'Linux',
      appVersion: '1.0.0',
      systemLangCode: 'en',
      langPack: '',
      langCode: 'en',
      query: const t.HelpGetConfig(),
    );

    print('Sending code to $phoneNumber...');
    final response = await client.invoke(t.AuthSendCode(
      apiId: apiId,
      apiHash: apiHash,
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
      print('Telegram Error: ${response.error!.errorMessage}');
    } else {
      print('Success! Code sent. Result: ${response.result}');
    }

    exit(0);
  } catch (e) {
    print('Exception during test: $e');
    exit(1);
  }
}

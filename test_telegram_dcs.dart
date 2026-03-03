
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

Future<void> testWithDc(int dcId, String ip, int port) async {
  print('Testing with DC $dcId ($ip:$port)...');

  final apiId = 20690169;
  final apiHash = '4222211cf4f8180a88b2b66ffa5420b0';
  final phoneNumber = '5587996156854';

  try {
    final socket = await Socket.connect(ip, port).timeout(const Duration(seconds: 10));
    final tgSocket = IoSocket(socket);
    final obfuscation = tg.Obfuscation.random(false, dcId);
    final idGenerator = tg.MessageIdGenerator();

    await tgSocket.send(obfuscation.preamble);

    print('Authorizing on DC $dcId...');
    final authKey = await tg.Client.authorize(
      tgSocket,
      obfuscation,
      idGenerator,
    );

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
      print('Telegram Error on DC $dcId: ${response.error!.errorMessage}');
    } else {
      print('Success on DC $dcId! Code sent. Result: ${response.result}');
    }

    await socket.close();
  } catch (e) {
    print('Exception on DC $dcId: $e');
  }
}

void main() async {
  // Test DC 1 and DC 4 (standard production DCs)
  await testWithDc(1, '149.154.167.50', 443);
  print('---');
  await testWithDc(4, '149.154.167.91', 443);
}

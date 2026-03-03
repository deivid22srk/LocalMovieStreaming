
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
       final err = response.error!.errorMessage;
       print('Telegram Error on DC $dcId: $err');
       if (err.startsWith('PHONE_MIGRATE_')) {
          final nextDc = int.parse(err.split('_').last);
          print('User needs to migrate to DC $nextDc');
       }
    } else {
      print('Success on DC $dcId! Code sent. Result: ${response.result}');
    }

    await socket.close();
  } catch (e) {
    print('Exception on DC $dcId: $e');
  }
}

void main() async {
  for (int i = 1; i <= 5; i++) {
     String ip = '';
     if (i == 1) ip = '149.154.167.50';
     if (i == 2) ip = '149.154.167.51';
     if (i == 3) ip = '149.154.175.100';
     if (i == 4) ip = '149.154.167.91';
     if (i == 5) ip = '149.154.167.92';

     await testWithDc(i, ip, 443);
     print('---');
  }
}

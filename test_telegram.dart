
import 'dart:io';
import 'package:t/t.dart' as t;

// A simple script to test if the library can connect and send a code
// Note: This needs to run in the Dart VM, not Web.

void main() async {
  print('Testing Telegram connection...');

  final apiId = 20690169;
  final apiHash = '4222211cf4f8180a88b2b66ffa5420b0';
  final phoneNumber = '5587996156854';

  try {
    final client = t.Telegram(
      apiId: apiId,
      apiHash: apiHash,
    );

    print('Connecting to Telegram...');
    await client.connect();
    print('Connected.');

    print('Sending code to $phoneNumber...');
    final response = await client.auth.sendCode(
      phoneNumber: phoneNumber,
      settings: const t.CodeSettings(
        allowFlashcall: false,
        currentNumber: true,
        allowAppHash: false,
        allowMissedCall: false,
        allowFirebase: false,
        unknownNumber: false,
      ),
    );

    if (response.error != null) {
      print('Telegram Error: ${response.error!.errorMessage}');
    } else {
      print('Success! Code sent. Response: ${response.result}');
    }

    exit(0);
  } catch (e) {
    print('Exception during test: $e');
    exit(1);
  }
}

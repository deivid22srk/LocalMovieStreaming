import 'package:flutter/services.dart';

class NativePlayerService {
  static const _channel = MethodChannel('com.localmovie.streaming/player');

  static Future<int> playVideo(String url, String title, int position) async {
    try {
      final int result = await _channel.invokeMethod('playVideo', {
        'url': url,
        'title': title,
        'position': position,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to play native video: '${e.message}'.");
      return position;
    }
  }
}

import 'dart:io';

import 'package:flutter/services.dart';

/// Opens media in ToolLab's Android-native player.
class NativeMediaPlayer {
  NativeMediaPlayer._();

  static const String preferenceId = 'internal-media-player';
  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/native_media_player',
  );

  static bool get isSupported => Platform.isAndroid;

  static Future<void> open({
    required String path,
    required String mimeType,
  }) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('open', {
      'path': path,
      'mimeType': mimeType,
    });
  }
}

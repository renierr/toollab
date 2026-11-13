import 'dart:io';

import 'package:flutter/services.dart';

/// Reads text aloud with the Android text-to-speech engine.
class TextToSpeechService {
  TextToSpeechService._();

  static const _channel = MethodChannel('de.renier.tool_lab/tts');

  static bool get isSupported => Platform.isAndroid;

  /// Completes with true once read to the end, false when stopped.
  /// Throws [TextToSpeechException] without an engine or voice for [language].
  static Future<bool> speak(String text, {String? language}) async {
    try {
      return await _channel.invokeMethod<bool>('speak', {
            'text': text,
            'language': language,
          }) ??
          false;
    } on PlatformException catch (e) {
      throw TextToSpeechException(
        e.code == 'language_unavailable'
            ? TextToSpeechError.languageUnavailable
            : TextToSpeechError.unavailable,
      );
    }
  }

  static Future<bool> isLanguageAvailable(String language) async =>
      await _channel.invokeMethod<bool>('isLanguageAvailable', {
        'language': language,
      }) ??
      false;

  static Future<void> stop() => _channel.invokeMethod<void>('stop');

  /// Shuts the engine down; the next [speak] starts it again.
  static Future<void> release() => _channel.invokeMethod<void>('release');
}

enum TextToSpeechError { unavailable, languageUnavailable }

class TextToSpeechException implements Exception {
  final TextToSpeechError error;
  const TextToSpeechException(this.error);

  @override
  String toString() => 'TextToSpeechException(${error.name})';
}

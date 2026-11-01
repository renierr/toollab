import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How the app decides whether it runs on a TV driven by a remote control.
enum TvMode {
  /// Follow the platform: Android TV and Google TV report a television UI mode.
  auto('auto'),
  on('on'),
  off('off');

  const TvMode(this.storageValue);

  final String storageValue;

  static TvMode fromStorage(String? value) => TvMode.values.firstWhere(
    (m) => m.storageValue == value,
    orElse: () => TvMode.auto,
  );
}

class TvService {
  static const MethodChannel _channel = MethodChannel('de.renier.tool_lab/tv');

  /// True when the platform reports a television UI mode. Detection is
  /// best-effort: a missing plugin means a plain phone build.
  static Future<bool> isTelevision() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

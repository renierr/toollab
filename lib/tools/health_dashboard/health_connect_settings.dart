import 'dart:io';

import 'package:flutter/services.dart';

class HealthConnectSettings {
  HealthConnectSettings._();

  static const _channel = MethodChannel('de.renier.tool_lab/health_connect');

  /// Opens Health Connect's own screen. Returns true when only the app-info
  /// fallback could be opened, which is what happens on a device whose Health
  /// Connect exposes no settings action - the per-app deep link is
  /// signature-protected and never available to us.
  static Future<bool> open() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMapMethod<String, Object?>(
      'openSettings',
    );
    return result?['fallback'] == true;
  }
}

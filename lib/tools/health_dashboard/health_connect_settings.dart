import 'dart:io';

import 'package:flutter/services.dart';

class HealthConnectSettings {
  HealthConnectSettings._();

  static const _channel = MethodChannel('de.renier.tool_lab/health_connect');

  static Future<void> open() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openSettings');
  }
}

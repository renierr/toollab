import 'dart:io';

import 'package:flutter/services.dart';

/// Native calls that work in every engine, including headless background runs.
class ToolLabBridge {
  ToolLabBridge._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/bridge',
  );

  /// Sends [action] to a receiver inside the app package. Values of [extras]
  /// must be String, int, double or bool.
  static Future<void> broadcast(
    String action, [
    Map<String, Object> extras = const {},
  ]) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('broadcast', {
      'action': action,
      'extras': extras,
    });
  }

  static Future<bool> notificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('notificationsEnabled') ?? true;
  }

  static Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openNotificationSettings');
  }
}

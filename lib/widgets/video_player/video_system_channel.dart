import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/debug_log.dart';

/// Android helpers for content:// videos, media volume and screen brightness.
class VideoSystemChannel {
  VideoSystemChannel._();

  static const MethodChannel channel = MethodChannel(
    'de.renier.tool_lab/video_system',
  );

  /// The readable file behind a content URI, so the folder can be browsed and
  /// access survives a restart; the URI itself without one or storage access.
  static Future<Uri> preferFile(Uri source) async {
    if (!Platform.isAndroid || !source.isScheme('content')) return source;
    try {
      final path = await channel.invokeMethod<String>('resolvePath', {
        'uri': source.toString(),
      });
      return path == null ? source : Uri.file(path);
    } catch (e) {
      errorLog('[VideoSystemChannel] resolvePath failed: $e');
      return source;
    }
  }

  /// Keeps read access to a picked document after the app restarts.
  static Future<void> persist(Uri source) => _uriCall('persistUri', source);

  static Future<void> release(Uri source) => _uriCall('releaseUri', source);

  static Future<double> volume() => _read('getVolume', fallback: 0);

  static Future<void> setVolume(double value) =>
      _write('setVolume', {'value': value});

  static Future<double> brightness() => _read('getBrightness', fallback: 0.5);

  /// Null hands the screen brightness back to the system.
  static Future<void> setBrightness(double? value) =>
      _write('setBrightness', value == null ? null : {'value': value});

  static Future<void> _uriCall(String method, Uri source) async {
    if (!Platform.isAndroid || !source.isScheme('content')) return;
    try {
      await channel.invokeMethod<void>(method, {'uri': source.toString()});
    } catch (e) {
      debugLog('[VideoSystemChannel] $method failed: $e');
    }
  }

  static Future<double> _read(String method, {required double fallback}) async {
    try {
      return await channel.invokeMethod<double>(method) ?? fallback;
    } catch (e) {
      errorLog('[VideoSystemChannel] $method failed: $e');
      return fallback;
    }
  }

  static Future<void> _write(String method, Map<String, Object?>? args) async {
    try {
      await channel.invokeMethod<void>(method, args);
    } catch (e) {
      errorLog('[VideoSystemChannel] $method failed: $e');
    }
  }
}

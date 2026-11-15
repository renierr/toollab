import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/debug_log.dart';

/// Android helpers for content:// videos.
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
  static Future<void> persist(Uri source) => _call('persistUri', source);

  static Future<void> release(Uri source) => _call('releaseUri', source);

  static Future<void> _call(String method, Uri source) async {
    if (!Platform.isAndroid || !source.isScheme('content')) return;
    try {
      await channel.invokeMethod<void>(method, {'uri': source.toString()});
    } catch (e) {
      debugLog('[VideoSystemChannel] $method failed: $e');
    }
  }
}

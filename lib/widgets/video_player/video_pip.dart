import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/debug_log.dart';

/// Android picture-in-picture for the one open video player.
class VideoPip {
  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/video_pip',
  );

  static Future<bool>? _supported;

  /// Whether the device offers picture-in-picture at all.
  static Future<bool> isSupported() {
    if (!Platform.isAndroid) return Future.value(false);
    return _supported ??= _channel
        .invokeMethod<bool>('isSupported')
        .then((value) => value ?? false)
        .catchError((Object e) {
          errorLog('[VideoPip] isSupported failed: $e');
          return false;
        });
  }

  final ValueNotifier<bool> active = ValueNotifier(false);
  final void Function(String action) onAction;
  final VoidCallback onDismissed;
  Map<String, String> labels;

  /// Enter on leaving the app while playing; the button works either way.
  bool autoEnter;

  ({bool playing, bool seekable, double aspectRatio})? _sent;

  VideoPip({
    required this.onAction,
    required this.onDismissed,
    required this.labels,
    required this.autoEnter,
  }) {
    if (Platform.isAndroid) _channel.setMethodCallHandler(_onCall);
  }

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipChanged':
        active.value = call.arguments as bool;
      case 'onAction':
        onAction(call.arguments as String);
      case 'onDismissed':
        onDismissed();
    }
  }

  /// Lets the activity enter picture-in-picture while [playing], and shows
  /// matching controls in the window.
  Future<void> update({
    required bool playing,
    required bool seekable,
    required double aspectRatio,
  }) async {
    final next = (
      playing: playing,
      seekable: seekable,
      aspectRatio: aspectRatio,
    );
    if (!Platform.isAndroid || next == _sent) return;
    final first = _sent == null;
    _sent = next;
    await _invoke('update', {
      'enabled': true,
      'autoEnter': autoEnter,
      'playing': playing,
      'seekable': seekable,
      'aspectRatio': aspectRatio,
      if (first) 'labels': labels,
    });
  }

  /// Takes effect with the next [update].
  void reconfigure({
    required bool autoEnter,
    required Map<String, String> labels,
  }) {
    this.autoEnter = autoEnter;
    this.labels = labels;
    _sent = null;
  }

  Future<bool> enter() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('enter') ?? false;
    } catch (e) {
      errorLog('[VideoPip] enter failed: $e');
      return false;
    }
  }

  /// Sends the task to the background, which closes the window.
  Future<void> leave() => _invoke('leave', const {});

  Future<void> dispose() async {
    active.dispose();
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(null);
    await _invoke('update', {'enabled': false, 'playing': false});
  }

  static Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      errorLog('[VideoPip] $method failed: $e');
    }
  }
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MediaPlaybackStatus { playing, paused, stopped }

enum MediaButton { play, pause, stop, next, previous }

class MediaMetadata {
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;

  const MediaMetadata({
    required this.title,
    this.artist,
    this.album,
    this.duration,
  });
}

abstract class MediaControlsService {
  MediaControlsService._();

  static MediaControlsService? _instance;

  static MediaControlsService get instance {
    if (_instance == null) {
      _instance = _create();
      unawaited(_instance!.init());
    }
    return _instance!;
  }

  static MediaControlsService _create() {
    if (defaultTargetPlatform == TargetPlatform.windows || Platform.isWindows) {
      return MediaControlsWindowsImpl();
    }
    return MediaControlsStubImpl();
  }

  static void reset({MediaControlsService? override}) {
    if (override != null) {
      _instance = override;
    } else {
      _instance = null;
    }
  }

  Future<void> init();
  Future<void> updateMetadata(MediaMetadata metadata);
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status);
  Future<void> updatePosition(Duration position);
  Future<void> clear();
  Stream<MediaButton> get buttonEvents;
  Future<void> dispose();
}

class MediaControlsStubImpl extends MediaControlsService {
  MediaControlsStubImpl() : super._();

  final StreamController<MediaButton> _controller =
      StreamController<MediaButton>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {}

  @override
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status) async {}

  @override
  Future<void> updatePosition(Duration position) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<MediaButton> get buttonEvents => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class MediaControlsWindowsImpl extends MediaControlsService {
  MediaControlsWindowsImpl() : super._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/media_controls',
  );

  final StreamController<MediaButton> _controller =
      StreamController<MediaButton>.broadcast();
  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_disposed) return;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onButton') {
      final button = _parseButton(call.arguments as String);
      if (button != null && !_controller.isClosed) {
        _controller.add(button);
      }
    }
  }

  static MediaButton? _parseButton(String name) {
    switch (name) {
      case 'play':
        return MediaButton.play;
      case 'pause':
        return MediaButton.pause;
      case 'stop':
        return MediaButton.stop;
      case 'next':
        return MediaButton.next;
      case 'previous':
        return MediaButton.previous;
    }
    return null;
  }

  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('updateMetadata', {
        'title': metadata.title,
        if (metadata.artist != null) 'artist': metadata.artist,
        if (metadata.album != null) 'album': metadata.album,
        if (metadata.duration != null)
          'durationMs': metadata.duration!.inMilliseconds,
      });
    } catch (e) {
      debugPrint('[$_logPrefix] updateMetadata failed: $e');
    }
  }

  @override
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('updatePlaybackStatus', status.name);
    } catch (e) {
      debugPrint('[$_logPrefix] updatePlaybackStatus failed: $e');
    }
  }

  @override
  Future<void> updatePosition(Duration position) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>(
        'updatePosition',
        position.inMilliseconds,
      );
    } catch (e) {
      debugPrint('[$_logPrefix] updatePosition failed: $e');
    }
  }

  @override
  Future<void> clear() async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (e) {
      debugPrint('[$_logPrefix] clear failed: $e');
    }
  }

  @override
  Stream<MediaButton> get buttonEvents => _controller.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
    await _controller.close();
    _channel.setMethodCallHandler(null);
  }

  static const String _logPrefix = 'MediaControlsWindows';
}

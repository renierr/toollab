import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'media_kit_video_backend.dart';
import 'native_video_backend.dart';

@immutable
class VideoPlaybackState {
  final bool initialized;
  final bool playing;
  final bool buffering;
  final bool completed;
  final Duration position;
  final Duration duration;
  final double aspectRatio;

  /// The decoded frame's width in pixels, when the backend knows it.
  final int? videoWidth;
  final double volume;
  final String? error;

  const VideoPlaybackState({
    this.initialized = false,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.videoWidth,
    this.volume = 1,
    this.error,
  });
}

/// One playback engine per platform behind a single surface: ExoPlayer (via
/// video_player) on Android, libmpv (via media_kit) on Windows and Linux.
abstract class VideoBackend {
  ValueNotifier<VideoPlaybackState> get state;

  Future<void> open(Uri source, {required bool loop, Duration? start});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);

  /// PNG of the current frame when the view is not a Flutter texture (Android's
  /// SurfaceView); null means the page reads the frame back from Flutter.
  Future<Uint8List?> nativeFrame();
  Widget buildView(BuildContext context);
  Future<void> dispose();

  static bool get isSupported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  static VideoBackend create() =>
      Platform.isAndroid ? NativeVideoBackend() : MediaKitVideoBackend();
}

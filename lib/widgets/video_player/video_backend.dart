import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'media_kit_video_backend.dart';
import 'native_video_backend.dart';

/// An audio or subtitle track the viewer can pick.
@immutable
class VideoTrackOption {
  final String id;
  final String? title;
  final String? language;
  final String? codec;
  final bool selected;

  const VideoTrackOption({
    required this.id,
    this.title,
    this.language,
    this.codec,
    this.selected = false,
  });

  @override
  bool operator ==(Object other) =>
      other is VideoTrackOption &&
      other.id == id &&
      other.title == title &&
      other.language == language &&
      other.codec == codec &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(id, title, language, codec, selected);
}

/// Stream details for the info dialog; null where the backend cannot tell.
class VideoStreamInfo {
  final int? width;
  final int? height;
  final String? videoCodec;
  final String? decoder;
  final double? frameRate;
  final int? videoBitrate;
  final String? audioCodec;
  final int? sampleRate;
  final int? channels;
  final int? audioBitrate;

  const VideoStreamInfo({
    this.width,
    this.height,
    this.videoCodec,
    this.decoder,
    this.frameRate,
    this.videoBitrate,
    this.audioCodec,
    this.sampleRate,
    this.channels,
    this.audioBitrate,
  });
}

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
  final double speed;
  final List<VideoTrackOption> audioTracks;
  final List<VideoTrackOption> subtitleTracks;
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
    this.speed = 1,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
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
  Future<void> setSpeed(double speed);
  Future<void> selectAudioTrack(String id);

  /// Null turns subtitles off.
  Future<void> selectSubtitleTrack(String? id);

  /// Adds an SRT or WebVTT file as a subtitle track and selects it.
  Future<void> addSubtitleFile(XFile file);
  Future<VideoStreamInfo> streamInfo();

  /// PNG of the current frame when the view is not a Flutter texture (Android's
  /// SurfaceView); null means the page reads the frame back from Flutter.
  Future<Uint8List?> nativeFrame();
  Widget buildView(BuildContext context);
  Future<void> dispose();

  static bool get isSupported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  /// [hardwareDecoding] applies to desktop; Android picks its decoder itself.
  static VideoBackend create({bool hardwareDecoding = true}) =>
      Platform.isAndroid
      ? NativeVideoBackend()
      : MediaKitVideoBackend(hardwareDecoding: hardwareDecoding);
}

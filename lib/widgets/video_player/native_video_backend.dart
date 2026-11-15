import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:video_player/video_player.dart';

import 'video_backend.dart';

class NativeVideoBackend implements VideoBackend {
  @override
  final ValueNotifier<VideoPlaybackState> state = ValueNotifier(
    const VideoPlaybackState(),
  );

  VideoPlayerController? _controller;
  Uri? _source;
  List<VideoTrackOption> _audioTracks = const [];
  bool _audioTracksRetried = false;
  final List<_SubtitleFile> _subtitles = [];
  String? _subtitleId;

  static const _systemChannel = MethodChannel(
    'de.renier.tool_lab/video_system',
  );

  @override
  Future<void> open(Uri source, {required bool loop, Duration? start}) async {
    // A SurfaceView lets Android scale the decoder output itself; the texture
    // path draws it shrunk into a corner on some Android TV decoders.
    final controller = source.isScheme('file')
        ? VideoPlayerController.file(
            File.fromUri(source),
            viewType: VideoViewType.platformView,
          )
        : VideoPlayerController.networkUrl(
            source,
            viewType: VideoViewType.platformView,
          );
    _controller = controller;
    _source = source;
    controller.addListener(_sync);
    try {
      await controller.initialize();
      await _loadAudioTracks();
      if (source.isScheme('file')) await _loadSidecarSubtitles(source);
      await controller.setLooping(loop);
      if (start != null && start > Duration.zero) {
        await controller.seekTo(start);
      }
      await controller.play();
    } catch (e) {
      state.value = VideoPlaybackState(error: '$e');
    }
  }

  Future<void> _loadAudioTracks() async {
    final controller = _controller;
    if (controller == null || !controller.isAudioTrackSupportAvailable()) {
      return;
    }
    try {
      final tracks = await controller.getAudioTracks();
      _audioTracks = [
        for (final t in tracks)
          VideoTrackOption(
            id: t.id,
            title: t.label,
            language: t.language,
            codec: t.codec,
            selected: t.isSelected,
          ),
      ];
      _sync();
    } catch (e) {
      errorLog('[NativeVideoBackend] Audio tracks failed: $e');
    }
  }

  /// Subtitles next to the video that share its name, like `movie.en.srt`.
  Future<void> _loadSidecarSubtitles(Uri source) async {
    try {
      final video = File.fromUri(source);
      final base = p.basenameWithoutExtension(video.path);
      final candidates = await video.parent
          .list()
          .where((e) => e is File)
          .map((e) => e.path)
          .where((path) {
            final name = p.basename(path);
            return _SubtitleFile.isSupported(name) &&
                (p.basenameWithoutExtension(name) == base ||
                    name.startsWith('$base.'));
          })
          .toList();
      candidates.sort();
      for (final path in candidates) {
        await _addSubtitle(p.basename(path), await File(path).readAsBytes());
      }
      if (_subtitles.isNotEmpty) await selectSubtitleTrack(_subtitles.first.id);
    } catch (e) {
      debugLog('[NativeVideoBackend] No sidecar subtitles: $e');
    }
  }

  Future<String> _addSubtitle(String name, List<int> bytes) async {
    final id = 'file-${_subtitles.length}';
    _subtitles.add(
      _SubtitleFile(
        id: id,
        name: name,
        content: utf8.decode(bytes, allowMalformed: true),
      ),
    );
    return id;
  }

  void _sync() {
    final value = _controller?.value;
    if (value == null) return;
    if (value.isPlaying && _audioTracks.isEmpty && !_audioTracksRetried) {
      // Some streams only report their tracks once playback starts.
      _audioTracksRetried = true;
      unawaited(_loadAudioTracks());
    }
    state.value = VideoPlaybackState(
      initialized: value.isInitialized,
      playing: value.isPlaying,
      buffering: value.isBuffering,
      completed: value.isCompleted,
      position: value.position,
      duration: value.duration,
      aspectRatio: value.isInitialized ? value.aspectRatio : 16 / 9,
      volume: value.volume,
      speed: value.playbackSpeed,
      audioTracks: _audioTracks,
      subtitleTracks: [
        for (final s in _subtitles)
          VideoTrackOption(
            id: s.id,
            title: s.name,
            codec: s.format,
            selected: s.id == _subtitleId,
          ),
      ],
      error: value.hasError ? value.errorDescription : null,
    );
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
    await controller.play();
  }

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seek(Duration position) async => _controller?.seekTo(position);

  @override
  Future<void> setVolume(double volume) async => _controller?.setVolume(volume);

  @override
  Future<void> setSpeed(double speed) async =>
      _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> selectAudioTrack(String id) async {
    await _controller?.selectAudioTrack(id);
    await _loadAudioTracks();
  }

  @override
  Future<void> selectSubtitleTrack(String? id) async {
    final controller = _controller;
    if (controller == null) return;
    final file = _subtitles.where((s) => s.id == id).firstOrNull;
    _subtitleId = file?.id;
    await controller.setClosedCaptionFile(
      file == null ? null : Future.value(file.parse()),
    );
    _sync();
  }

  @override
  Future<void> addSubtitleFile(XFile file) async {
    if (!_SubtitleFile.isSupported(file.name)) {
      throw UnsupportedError('Only SRT and WebVTT subtitles: ${file.name}');
    }
    final id = await _addSubtitle(file.name, await file.readAsBytes());
    await selectSubtitleTrack(id);
  }

  @override
  Future<VideoStreamInfo> streamInfo() async {
    final value = _controller?.value;
    final audio =
        _controller != null && _controller!.isAudioTrackSupportAvailable()
        ? (await _controller!.getAudioTracks())
              .where((t) => t.isSelected)
              .firstOrNull
        : null;
    Map<Object?, Object?>? videoFormat;
    Map<Object?, Object?>? audioFormat;
    final source = _source;
    if (source != null && source.isScheme('file')) {
      try {
        final tracks = await _systemChannel.invokeListMethod<Map>('tracks', {
          'path': File.fromUri(source).path,
        });
        for (final t in tracks ?? const <Map>[]) {
          final mime = t['mime'] as String? ?? '';
          if (mime.startsWith('video/')) videoFormat ??= t;
          if (mime.startsWith('audio/')) audioFormat ??= t;
        }
      } catch (e) {
        errorLog('[NativeVideoBackend] Track info failed: $e');
      }
    }
    String? codec(Map<Object?, Object?>? format) =>
        (format?['mime'] as String?)?.split('/').last;
    final size = value?.size;
    return VideoStreamInfo(
      width: size != null && size.width > 0 ? size.width.round() : null,
      height: size != null && size.height > 0 ? size.height.round() : null,
      videoCodec: codec(videoFormat),
      frameRate: (videoFormat?['frameRate'] as num?)?.toDouble(),
      videoBitrate: videoFormat?['bitrate'] as int?,
      audioCodec: audio?.codec ?? codec(audioFormat),
      sampleRate: audio?.sampleRate ?? audioFormat?['sampleRate'] as int?,
      channels: audio?.channelCount ?? audioFormat?['channels'] as int?,
      audioBitrate: audio?.bitrate ?? audioFormat?['bitrate'] as int?,
    );
  }

  static const _frameChannel = MethodChannel('de.renier.tool_lab/video_frame');

  @override
  Future<Uint8List?> nativeFrame() {
    final size = _controller?.value.size;
    return _frameChannel.invokeMethod<Uint8List>('capture', {
      'width': size?.width.round(),
      'height': size?.height.round(),
    });
  }

  @override
  Widget buildView(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(controller),
        _Captions(controller: controller),
      ],
    );
  }

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_sync);
    await _controller?.dispose();
    state.dispose();
  }
}

class _SubtitleFile {
  final String id;
  final String name;
  final String content;

  const _SubtitleFile({
    required this.id,
    required this.name,
    required this.content,
  });

  static bool isSupported(String name) {
    final ext = p.extension(name).toLowerCase();
    return ext == '.srt' || ext == '.vtt';
  }

  bool get _vtt =>
      p.extension(name).toLowerCase() == '.vtt' ||
      content.trimLeft().startsWith('WEBVTT');

  String get format => _vtt ? 'webvtt' : 'subrip';

  ClosedCaptionFile parse() =>
      _vtt ? WebVTTCaptionFile(content) : SubRipCaptionFile(content);
}

/// video_player only knows external caption files; it draws none itself.
class _Captions extends StatelessWidget {
  final VideoPlayerController controller;

  const _Captions({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxHeight / 18).clamp(12.0, 32.0);
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => ClosedCaption(
            text: value.caption.text,
            textStyle: TextStyle(fontSize: fontSize, color: Colors.white),
          ),
        );
      },
    );
  }
}

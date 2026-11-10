import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_backend.dart';

class MediaKitVideoBackend implements VideoBackend {
  static bool _initialized = false;

  @override
  final ValueNotifier<VideoPlaybackState> state = ValueNotifier(
    const VideoPlaybackState(),
  );

  late final Player _player;
  late final VideoController _video;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _loop = false;

  MediaKitVideoBackend() {
    if (!_initialized) {
      MediaKit.ensureInitialized();
      _initialized = true;
    }
    _player = Player();
    _video = VideoController(_player);
    final streams = _player.stream;
    _subscriptions.addAll([
      streams.playing.listen((_) => _sync()),
      streams.buffering.listen((_) => _sync()),
      streams.completed.listen((_) => _sync()),
      streams.position.listen((_) => _sync()),
      streams.duration.listen((_) => _sync()),
      streams.width.listen((_) => _sync()),
      streams.volume.listen((_) => _sync()),
      streams.error.listen((e) => _sync(error: e)),
    ]);
  }

  void _sync({String? error}) {
    final s = _player.state;
    final width = s.width ?? 0;
    final height = s.height ?? 0;
    state.value = VideoPlaybackState(
      initialized: s.duration > Duration.zero,
      playing: s.playing,
      buffering: s.buffering,
      completed: s.completed && !_loop,
      position: s.position,
      duration: s.duration,
      aspectRatio: width > 0 && height > 0 ? width / height : 16 / 9,
      volume: s.volume / 100,
      error: error ?? state.value.error,
    );
  }

  @override
  Future<void> open(Uri source, {required bool loop}) async {
    _loop = loop;
    await _player.setPlaylistMode(
      loop ? PlaylistMode.single : PlaylistMode.none,
    );
    await _player.open(Media(source.toString()));
  }

  @override
  Future<void> play() async {
    if (_player.state.completed) await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume * 100);

  @override
  Widget buildView(BuildContext context) =>
      Video(controller: _video, controls: NoVideoControls);

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    state.dispose();
  }
}

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'video_backend.dart';

class NativeVideoBackend implements VideoBackend {
  @override
  final ValueNotifier<VideoPlaybackState> state = ValueNotifier(
    const VideoPlaybackState(),
  );

  VideoPlayerController? _controller;

  @override
  Future<void> open(Uri source, {required bool loop}) async {
    final controller = source.isScheme('file')
        ? VideoPlayerController.file(File.fromUri(source))
        : VideoPlayerController.networkUrl(source);
    _controller = controller;
    controller.addListener(_sync);
    try {
      await controller.initialize();
      await controller.setLooping(loop);
      await controller.play();
    } catch (e) {
      state.value = VideoPlaybackState(error: '$e');
    }
  }

  void _sync() {
    final value = _controller?.value;
    if (value == null) return;
    state.value = VideoPlaybackState(
      initialized: value.isInitialized,
      playing: value.isPlaying,
      buffering: value.isBuffering,
      completed: value.isCompleted,
      position: value.position,
      duration: value.duration,
      aspectRatio: value.isInitialized ? value.aspectRatio : 16 / 9,
      volume: value.volume,
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
  Widget buildView(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return VideoPlayer(controller);
  }

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_sync);
    await _controller?.dispose();
    state.dispose();
  }
}

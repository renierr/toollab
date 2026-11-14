import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
      // A live stream may report no duration; its first frame still counts.
      initialized: s.duration > Duration.zero || width > 0,
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

  static String? _vaapiDevice;
  static bool _vaapiDeviceResolved = false;

  /// libva opens the first render node, which on hybrid laptops is often an
  /// NVIDIA GPU without a VA-API driver; the first other GPU decodes instead.
  static String? _resolveVaapiDevice() {
    if (_vaapiDeviceResolved) return _vaapiDevice;
    _vaapiDeviceResolved = true;
    try {
      final nodes =
          Directory('/sys/class/drm')
              .listSync()
              .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
              .where((name) => name.startsWith('renderD'))
              .toList()
            ..sort();
      String? first;
      var skipped = false;
      for (final name in nodes) {
        final vendor = File(
          '/sys/class/drm/$name/device/vendor',
        ).readAsStringSync().trim();
        if (vendor == '0x10de') {
          skipped = true;
          continue;
        }
        first ??= '/dev/dri/$name';
      }
      if (skipped) _vaapiDevice = first;
    } catch (_) {}
    return _vaapiDevice;
  }

  @override
  Future<void> open(Uri source, {required bool loop, Duration? start}) async {
    _loop = loop;
    final platform = _player.platform;
    final device = Platform.isLinux ? _resolveVaapiDevice() : null;
    if (device != null && platform is NativePlayer) {
      await platform.setProperty('vaapi-device', device);
    }
    await _player.setPlaylistMode(
      loop ? PlaylistMode.single : PlaylistMode.none,
    );
    await _player.open(Media(source.toString(), start: start));
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
  bool get canScreenshot => true;

  @override
  Future<Uint8List?> screenshot() => _player.screenshot(format: 'image/png');

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

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_backend.dart';
import 'video_player_settings.dart';
import 'video_subtitle_style.dart';

class MediaKitVideoBackend implements VideoBackend {
  static bool _initialized = false;

  @override
  final ValueNotifier<VideoPlaybackState> state = ValueNotifier(
    const VideoPlaybackState(),
  );

  @override
  VideoPlayerSettings settings;

  late final Player _player;
  late final VideoController _video;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _loop = false;

  MediaKitVideoBackend(this.settings) {
    if (!_initialized) {
      MediaKit.ensureInitialized();
      _initialized = true;
    }
    _player = Player();
    _video = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        hwdec: settings.hardwareDecoding ? null : 'no',
      ),
    );
    final streams = _player.stream;
    _subscriptions.addAll([
      streams.playing.listen((_) => _sync()),
      streams.buffering.listen((_) => _sync()),
      streams.completed.listen((_) => _sync()),
      streams.position.listen((_) => _sync()),
      streams.duration.listen((_) => _sync()),
      streams.width.listen((_) => _sync()),
      streams.volume.listen((_) => _sync()),
      streams.rate.listen((_) => _sync()),
      streams.tracks.listen((_) => _sync()),
      streams.track.listen((_) => _sync()),
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
      videoWidth: width > 0 ? width : null,
      volume: s.volume / 100,
      speed: s.rate,
      audioTracks: [
        for (final t in s.tracks.audio.where((t) => _isReal(t.id)))
          VideoTrackOption(
            id: t.id,
            title: t.title,
            language: t.language,
            codec: t.codec,
            selected: t.id == s.track.audio.id,
          ),
      ],
      subtitleTracks: [
        for (final t in s.tracks.subtitle.where((t) => _isReal(t.id)))
          VideoTrackOption(
            id: t.id,
            title: t.title,
            language: t.language,
            codec: t.codec,
            selected: t.id == s.track.subtitle.id,
          ),
      ],
      error: error ?? state.value.error,
    );
  }

  /// mpv lists `auto` and `no` next to the real tracks.
  static bool _isReal(String id) => id != 'auto' && id != 'no';

  /// The selected track, or the first real one while mpv still says `auto`.
  static T? _current<T>(List<T> tracks, T selected, String Function(T) id) {
    final real = tracks.where((t) => _isReal(id(t)));
    return real.where((t) => t == selected).firstOrNull ?? real.firstOrNull;
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
    if (platform is NativePlayer) {
      if (device != null) await platform.setProperty('vaapi-device', device);
      await platform.setProperty(
        'sub-auto',
        settings.sidecarSubtitles ? 'exact' : 'no',
      );
      await platform.setProperty(
        'alang',
        videoLanguageCodes(settings.audioLanguage).join(','),
      );
      await platform.setProperty(
        'slang',
        videoLanguageCodes(settings.subtitleLanguage).join(','),
      );
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
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> selectAudioTrack(String id) async {
    final track = _player.state.tracks.audio.where((t) => t.id == id);
    if (track.isNotEmpty) await _player.setAudioTrack(track.first);
  }

  @override
  Future<void> selectSubtitleTrack(String? id) async {
    if (id == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    final track = _player.state.tracks.subtitle.where((t) => t.id == id);
    if (track.isNotEmpty) await _player.setSubtitleTrack(track.first);
  }

  @override
  Future<void> addSubtitleFile(XFile file) =>
      _player.setSubtitleTrack(SubtitleTrack.uri(file.path, title: file.name));

  @override
  Future<VideoStreamInfo> streamInfo() async {
    final s = _player.state;
    final video = _current(s.tracks.video, s.track.video, (t) => t.id);
    final audio = _current(s.tracks.audio, s.track.audio, (t) => t.id);
    String? hwdec;
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        hwdec = await platform.getProperty('hwdec-current');
      } catch (_) {}
    }
    final decoder = video?.decoder;
    return VideoStreamInfo(
      width: s.videoParams.w ?? s.width,
      height: s.videoParams.h ?? s.height,
      videoCodec: video?.codec,
      decoder: hwdec == null || hwdec.isEmpty || hwdec == 'no'
          ? decoder
          : '${decoder ?? video?.codec ?? ''} ($hwdec)'.trim(),
      frameRate: video?.fps,
      videoBitrate: video?.bitrate,
      audioCodec: audio?.codec,
      sampleRate: s.audioParams.sampleRate ?? audio?.samplerate,
      channels: s.audioParams.channelCount ?? audio?.channelscount,
      audioBitrate: s.audioBitrate?.round() ?? audio?.bitrate,
    );
  }

  @override
  Future<Uint8List?> nativeFrame() async => null;

  @override
  Widget buildView(BuildContext context) => Video(
    controller: _video,
    controls: NoVideoControls,
    subtitleViewConfiguration: SubtitleViewConfiguration(
      style: videoSubtitleStyle(settings, 32),
    ),
  );

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    state.dispose();
  }
}

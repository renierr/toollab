import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/database_service.dart';
import '../../../services/foreground_runtime_service.dart';
import '../../../services/media_controls_service.dart';
import '../../../services/power_wake_lock_service.dart';
import '../focus_noise_sound.dart';
import 'noise_loop_builder.dart';
import 'noise_pcm_generator.dart';

class FocusNoisePlayer {
  FocusNoisePlayer._();

  /// Shared instance so playback survives leaving the tool page and keeps
  /// running in the background via the foreground service.
  static final FocusNoisePlayer instance = FocusNoisePlayer._();

  SoundHandle? _handle;
  AudioSource? _source;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _volume = 0.65;
  FocusNoiseSound? _currentSound;
  WakeLockLease? _partialWakeLock;
  ForegroundRuntimeLease? _foregroundRuntimeLease;

  /// Guards against a late-arriving [play] result overwriting a newer request.
  int _playGeneration = 0;

  /// Localized text for the background-playback foreground notification.
  /// Set by the page once a [BuildContext] is available; the page composes
  /// sound name and timer state into it and calls [refreshNotification].
  String notificationTitle = 'Focus noise active';
  String notificationText = 'ToolLab keeps ambient audio running';

  /// Invoked when playback is stopped from outside the app (the notification's
  /// stop action), so the page can sync its UI state.
  VoidCallback? onExternalStop;

  /// Invoked when play/pause changes from outside the app (notification
  /// buttons), so the page can resync its transport state.
  VoidCallback? onExternalStateChange;
  StreamSubscription<MediaButton>? _mediaButtonSub;

  void _initMediaControls() {
    _mediaButtonSub ??= MediaControlsService.instance.buttonEvents.listen((
      button,
    ) {
      switch (button) {
        case MediaButton.stop:
          unawaited(stop());
          onExternalStop?.call();
          break;
        case MediaButton.pause:
          pause();
          break;
        case MediaButton.play:
          resume();
          break;
        default:
          break;
      }
    });
  }

  void _updateMediaControls(String title, MediaPlaybackStatus status) {
    _initMediaControls();
    unawaited(
      MediaControlsService.instance.updateMetadata(
        MediaMetadata(
          title: title,
          supportedButtons: const [
            MediaButton.play,
            MediaButton.pause,
            MediaButton.stop,
          ],
        ),
      ),
    );
    unawaited(MediaControlsService.instance.updatePlaybackStatus(status));
  }

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get volume => _volume;
  FocusNoiseSound? get currentSound => _currentSound;

  Future<void> play(FocusNoiseSound sound) async {
    await _ensureInit();
    await stop();

    final int generation = ++_playGeneration;
    _currentSound = sound;
    await _acquireLocks();

    final AudioSource source = sound.isAsset
        ? await _loadAsset(sound)
        : await _loadGenerated(sound);

    // A newer play()/stop() ran while we were rendering/decoding — discard.
    if (generation != _playGeneration) {
      SoLoud.instance.disposeSource(source);
      return;
    }

    _source = source;
    _handle = SoLoud.instance.play(source, volume: _volume);
    SoLoud.instance.setLooping(_handle!, true);
    _isPlaying = true;
    _isPaused = false;
    _updateMediaControls(sound.name, MediaPlaybackStatus.playing);
  }

  void pause() {
    final SoundHandle? handle = _handle;
    if (handle == null || !_isPlaying || _isPaused) return;
    SoLoud.instance.setPause(handle, true);
    _isPaused = true;
    _refreshNotification();
    onExternalStateChange?.call();
  }

  void resume() {
    final SoundHandle? handle = _handle;
    if (handle == null || !_isPlaying || !_isPaused) return;
    SoLoud.instance.setPause(handle, false);
    _isPaused = false;
    _refreshNotification();
    onExternalStateChange?.call();
  }

  Future<AudioSource> _loadAsset(FocusNoiseSound sound) {
    return SoLoud.instance.loadAsset(sound.assetPath!);
  }

  Future<AudioSource> _loadGenerated(FocusNoiseSound sound) async {
    final GeneratedNoiseType type = switch (sound.id) {
      'white' => GeneratedNoiseType.white,
      'pink' => GeneratedNoiseType.pink,
      'brown' => GeneratedNoiseType.brown,
      'train' => GeneratedNoiseType.train,
      'green' => GeneratedNoiseType.green,
      _ => GeneratedNoiseType.pink,
    };
    final Uint8List wav = await NoiseLoopBuilder.buildWav(type: type);
    return SoLoud.instance.loadMem('focus_${sound.id}.wav', wav);
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    final SoundHandle? handle = _handle;
    if (handle != null) {
      SoLoud.instance.setVolume(handle, _volume);
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    _isPaused = false;
    _playGeneration++;

    unawaited(MediaControlsService.instance.clear());
    final SoundHandle? handle = _handle;
    if (handle != null) {
      await SoLoud.instance.stop(handle);
      _handle = null;
    }

    final AudioSource? source = _source;
    if (source != null) {
      SoLoud.instance.disposeSource(source);
      _source = null;
    }

    _releaseLocks();
  }

  Future<void> _ensureInit() async {
    if (!SoLoud.instance.isInitialized) {
      final lowLatencyVal = await DatabaseService.instance.getSetting(
        '_app',
        'low_latency_audio',
      );
      final lowLatency = lowLatencyVal != 'false';
      await SoLoud.instance.init(lowLatency: lowLatency);
    }
  }

  Future<void> _acquireLocks() async {
    _partialWakeLock ??= await PowerWakeLockService.acquirePartial();
    if (_foregroundRuntimeLease == null) {
      _foregroundRuntimeLease = await ForegroundRuntimeService.acquire(
        title: notificationTitle,
        text: notificationText,
        actions: const ['pause', 'stop'],
        // Media treatment without a seek bar: the shade lists it as active
        // audio playback.
        media: MediaNotificationData(
          title: _currentSound?.name ?? notificationTitle,
          positionMs: 0,
          playing: true,
        ),
      );
      ForegroundRuntimeService.addActionListener(_handleNotificationAction);
    }
  }

  /// Re-pushes the current title/text/actions/media state to the notification.
  /// The page composes [notificationText] (sound name, timer) and calls this
  /// when either changes; pause/resume use it internally.
  void refreshNotification() {
    if (_foregroundRuntimeLease == null || !_isPlaying) return;
    _refreshNotification();
  }

  void _refreshNotification() {
    final ForegroundRuntimeLease? lease = _foregroundRuntimeLease;
    if (lease == null) return;
    unawaited(
      lease.update(
        title: notificationTitle,
        text: notificationText,
        actions: _isPaused ? const ['play', 'stop'] : const ['pause', 'stop'],
        media: MediaNotificationData(
          title: _currentSound?.name ?? notificationTitle,
          positionMs: 0,
          playing: _isPlaying && !_isPaused,
        ),
      ),
    );
  }

  void _releaseLocks() {
    if (_foregroundRuntimeLease != null) {
      ForegroundRuntimeService.removeActionListener(_handleNotificationAction);
      final ForegroundRuntimeLease? lease = _foregroundRuntimeLease;
      _foregroundRuntimeLease = null;
      if (lease != null) unawaited(lease.release());
    }
    final WakeLockLease? wakeLock = _partialWakeLock;
    _partialWakeLock = null;
    if (wakeLock != null) unawaited(wakeLock.release());
  }

  void _handleNotificationAction(String action) {
    switch (action) {
      case 'stop':
        unawaited(stop());
        onExternalStop?.call();
        break;
      case 'pause':
        pause();
        break;
      case 'play':
        resume();
        break;
    }
  }

  Future<void> dispose() async {
    await stop();
    _mediaButtonSub?.cancel();
    _mediaButtonSub = null;
    onExternalStop = null;
    onExternalStateChange = null;
  }
}

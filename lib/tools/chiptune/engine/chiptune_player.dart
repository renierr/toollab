import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../helpers/system_audio_player.dart';
import '../../../services/database_service.dart';
import '../../../services/foreground_runtime_service.dart';
import '../../../services/media_controls_service.dart';
import '../../../services/power_wake_lock_service.dart';
import 'mixer.dart';
import 'module.dart';
import 'render_worker.dart';
import 'song_duration.dart';

enum ChiptunePlaybackState { stopped, playing, paused }

/// Current pattern-order position and row within the playing module.
class SongPosition {
  final int order;
  final int row;
  const SongPosition(this.order, this.row);

  @override
  bool operator ==(Object other) =>
      other is SongPosition && other.order == order && other.row == row;

  @override
  int get hashCode => Object.hash(order, row);
}

/// Drives the software [ChiptuneMixer] and streams its PCM output to SoLoud.
///
/// The mixer renders interleaved stereo float32 which is pushed into a SoLoud
/// buffer stream. A periodic feed loop keeps a small look-ahead buffer filled
/// so playback stays smooth without large latency.
class ChiptunePlayer {
  static const int sampleRate = 44100;
  static const String _logPrefix = '[ChiptunePlayer]';

  // Larger look-ahead keeps playback stable under background throttling.
  static const double _bufferAheadSeconds = 6.0;
  // How long before a song's end [onNearEnd] fires, giving the page time to
  // prefetch the next track so the transition is gapless.
  static const Duration _prefetchLead = Duration(seconds: 10);
  static const int _chunkFrames = 8192;
  static const Duration _feedIntervalForeground = Duration(milliseconds: 16);
  static const Duration _feedIntervalBackground = Duration(milliseconds: 48);
  static const Duration _uiUpdateIntervalForeground = Duration(
    milliseconds: 24,
  );
  static const Duration _elapsedUpdateIntervalForeground = Duration(
    milliseconds: 80,
  );

  final ChiptuneRenderWorker _renderWorker = ChiptuneRenderWorker();

  AudioSource? _stream;
  // A natively-decoded audio file (wav/mp3/ogg/flac). When set, playback runs
  // through SoLoud's own decoder + a lightweight position poll instead of the
  // software mixer + PCM feed loop used for tracker modules.
  AudioSource? _nativeSource;
  bool _isNative = false;
  // A file played by Android's own codecs through [SystemAudioPlayer]. Used for
  // formats neither the module parser nor SoLoud handles (aac, m4a, opus, ...).
  // Position, end-of-stream and visualizer data arrive as pushed events, so this
  // path needs neither the mixer feed loop nor a position poll.
  bool _isSystem = false;
  String? _systemPath;
  StreamSubscription<SystemAudioEvent>? _systemSubscription;
  SoundHandle? _handle;
  Timer? _feedTimer;
  bool _feedInProgress = false;
  StreamSubscription<RenderRowEvent>? _rowSubscription;
  StreamSubscription<void>? _endedSubscription;

  ModuleFile? _module;
  WorkletModule? _worklet;
  Duration _totalDuration = Duration.zero;

  /// Added to the audio stream's own consumed-time so the elapsed read-out
  /// stays correct after a seek (the stream timer restarts from zero on seek).
  Duration _elapsedBase = Duration.zero;
  WakeLockLease? _partialWakeLock;
  ForegroundRuntimeLease? _foregroundRuntimeLease;
  DateTime? _lastUiUpdateAt;
  DateTime? _lastElapsedUpdateAt;
  DateTime? _lastNotificationUpdateAt;
  bool _uiUpdatesEnabled = true;
  Duration _feedInterval = _feedIntervalForeground;
  Duration _uiUpdateInterval = _uiUpdateIntervalForeground;
  Duration _elapsedUpdateInterval = _elapsedUpdateIntervalForeground;
  bool _ended = false;
  bool _rendererEnded = false;
  bool _nearEndFired = false;
  double _volume = 0.7;
  double _stereoWidth = 1.0;
  ChiptuneInterpolation _interpolation = ChiptuneInterpolation.sinc;
  double _preAmp = defaultPreAmp;
  ChiptuneAmigaFilter _amigaFilter = ChiptuneAmigaFilter.auto;
  double _rampStep = defaultRampStep;
  double _modSeparation = defaultModSeparation;
  bool _looping = false;
  int? _savedDeviceId;

  /// Localized text for the background-playback foreground notification.
  /// Set by the page once a [BuildContext] is available.
  String notificationTitle = 'Chiptune playback active';
  String notificationText = 'ToolLab keeps audio running in background';

  // Reactive outputs for the UI.
  final ValueNotifier<ChiptunePlaybackState> state = ValueNotifier(
    ChiptunePlaybackState.stopped,
  );
  final ValueNotifier<SongPosition> position = ValueNotifier(
    const SongPosition(0, 0),
  );
  final ValueNotifier<List<bool>> channelActivity = ValueNotifier(const []);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// Waveform/spectrum captured from the Android output mix during system
  /// playback. Null on every other path (those read SoLoud's own audio data).
  final ValueNotifier<SystemAudioSpectrum?> systemSpectrum = ValueNotifier(
    null,
  );

  /// Fired once when a non-looping song reaches its end.
  VoidCallback? onEnded;

  /// Fired when 'next' is clicked in the foreground service notification.
  VoidCallback? onNext;

  /// Fired once per song, [_prefetchLead] before its end; re-armed when a fresh
  /// song starts. Lets the page prefetch the next track for a gapless jump.
  VoidCallback? onNearEnd;

  /// Set by the page. Returns true when a song reaching its end will auto-advance
  /// to another track (random mode, or a following archived module). In that case
  /// the wakelock + foreground service must stay held across the (possibly slow,
  /// background) fetch of the next track instead of being released — releasing the
  /// last lease tears down the foreground service and lets Android suspend/kill the
  /// process mid-fetch, so the next track never starts.
  bool Function()? shouldKeepPlaybackAlive;

  ModuleFile? get module => _module;
  bool get isPlaying => state.value == ChiptunePlaybackState.playing;
  bool get hasModule => _worklet != null;

  /// True when the loaded source is a natively-decoded audio file rather than a
  /// tracker module.
  bool get isNative => _isNative;

  /// True when the loaded source plays through Android's system codecs.
  bool get isSystem => _isSystem;

  /// True for any plain audio file (SoLoud-decoded or system-decoded) — i.e. the
  /// tracker-specific UI (patterns, channels, samples, tweaks) does not apply.
  bool get isPlainAudio => _isNative || _isSystem;

  /// True when anything playable is loaded (module, native or system audio).
  bool get hasAudio => hasModule || _nativeSource != null || _isSystem;

  /// Estimated full play duration of the loaded module (zero if none / unknown).
  Duration get totalDuration => _totalDuration;

  void setUiUpdatesEnabled(bool enabled) {
    _uiUpdatesEnabled = enabled;
    _feedInterval = enabled ? _feedIntervalForeground : _feedIntervalBackground;
    _uiUpdateInterval = enabled
        ? _uiUpdateIntervalForeground
        : const Duration(hours: 1);
    _elapsedUpdateInterval = enabled
        ? _elapsedUpdateIntervalForeground
        : const Duration(hours: 1);
    if (!enabled) {
      _lastUiUpdateAt = null;
      _lastElapsedUpdateAt = null;
      _lastNotificationUpdateAt = null;
    }
  }

  ChiptunePlayer() {
    _rowSubscription = _renderWorker.onRow.listen((event) {
      if (!_uiUpdatesEnabled) return;
      final DateTime now = DateTime.now();
      final DateTime? last = _lastUiUpdateAt;
      if (last != null && now.difference(last) < _uiUpdateInterval) {
        return;
      }
      _lastUiUpdateAt = now;

      final SongPosition next = SongPosition(event.order, event.row);
      if (position.value != next) {
        position.value = next;
      }

      final List<bool> previous = channelActivity.value;
      bool changed = previous.length != event.activeChannels.length;
      if (!changed) {
        for (int i = 0; i < event.activeChannels.length; i++) {
          if (previous[i] != event.activeChannels[i]) {
            changed = true;
            break;
          }
        }
      }
      if (changed) {
        channelActivity.value = List<bool>.from(
          event.activeChannels,
          growable: false,
        );
      }
    });
    _endedSubscription = _renderWorker.onEnded.listen((_) {
      _rendererEnded = true;
    });
  }

  /// Total rows across the whole order list (for seek slider math).
  int get totalRows {
    final mod = _module;
    if (mod == null) return 1;
    int total = 0;
    for (final patIdx in mod.sequence) {
      if (patIdx >= 0 && patIdx < mod.patterns.length) {
        total += mod.patterns[patIdx].rows.length;
      }
    }
    return total > 0 ? total : 1;
  }

  /// Loads a parsed module but does not start playback.
  void loadModule(ModuleFile mod) {
    _stopInternal();
    // _stopInternal tears down the handle/stream/feed loop; the state must
    // follow, otherwise a load-without-play (e.g. "load another") leaves state
    // stuck at `playing` with no handle — the play/pause button then no-ops and
    // the tool appears frozen.
    state.value = ChiptunePlaybackState.stopped;
    _disposeNativeSource();
    _releaseSystemSource();
    _isNative = false;
    _module = mod;
    _worklet = serializeModuleForWorklet(mod);
    _totalDuration = estimateSongDuration(mod);
    _elapsedBase = Duration.zero;
    channelActivity.value = List<bool>.filled(mod.channels, false);
    position.value = const SongPosition(0, 0);
    elapsed.value = Duration.zero;
  }

  /// Loads a natively-decoded audio file (wav/mp3/ogg/flac) but does not start
  /// playback. [name] is only used as a SoLoud identifier for the loaded source.
  Future<void> loadAudio(Uint8List bytes, String name) async {
    _stopInternal();
    state.value = ChiptunePlaybackState.stopped;
    await _ensureInit();
    _disposeNativeSource();
    _releaseSystemSource();
    _module = null;
    _worklet = null;
    _isNative = true;
    _nativeSource = await SoLoud.instance.loadMem(name, bytes);
    _totalDuration = SoLoud.instance.getLength(_nativeSource!);
    _elapsedBase = Duration.zero;
    channelActivity.value = const [];
    position.value = const SongPosition(0, 0);
    elapsed.value = Duration.zero;
  }

  /// Prepares [path] for playback through Android's system codecs. Returns
  /// `false` when they cannot open the file, leaving no source loaded so callers
  /// can fall back to another handler.
  Future<bool> loadSystemAudio(String path) async {
    _stopInternal();
    state.value = ChiptunePlaybackState.stopped;
    _disposeNativeSource();
    _releaseSystemSource();
    final duration = await SystemAudioPlayer.instance.load(path);
    if (duration == null) return false;
    _module = null;
    _worklet = null;
    _isNative = false;
    _isSystem = true;
    _systemPath = path;
    _totalDuration = duration;
    _elapsedBase = Duration.zero;
    channelActivity.value = const [];
    position.value = const SongPosition(0, 0);
    elapsed.value = Duration.zero;
    systemSpectrum.value = null;
    _listenToSystemEvents();
    return true;
  }

  void _listenToSystemEvents() {
    _systemSubscription ??= SystemAudioPlayer.instance.events.listen(
      _onSystemEvent,
      onError: (Object e) => debugPrint('$_logPrefix system audio event: $e'),
    );
  }

  void _onSystemEvent(SystemAudioEvent event) {
    if (!_isSystem) return;

    final spectrum = event.spectrum;
    if (spectrum != null && _uiUpdatesEnabled) {
      systemSpectrum.value = spectrum;
    }

    if (event.completed) {
      if (_looping) return;
      _ended = true;
      _onSongEnded();
      return;
    }

    final DateTime now = DateTime.now();
    if (_uiUpdatesEnabled) {
      final DateTime? last = _lastElapsedUpdateAt;
      if (last == null || now.difference(last) >= _elapsedUpdateInterval) {
        _lastElapsedUpdateAt = now;
        elapsed.value = event.position;
      }
    }

    if (!_nearEndFired &&
        !_looping &&
        onNearEnd != null &&
        _totalDuration > Duration.zero &&
        event.position >= _totalDuration - _prefetchLead) {
      _nearEndFired = true;
      onNearEnd!.call();
    }

    _maybePushNotificationUpdate(now);
  }

  void _releaseSystemSource() {
    if (!_isSystem && _systemPath == null) return;
    _isSystem = false;
    _systemPath = null;
    systemSpectrum.value = null;
    unawaited(SystemAudioPlayer.instance.release());
  }

  void _disposeNativeSource() {
    final source = _nativeSource;
    _nativeSource = null;
    if (source != null) {
      unawaited(SoLoud.instance.disposeSource(source));
    }
  }

  Future<void> play() async {
    if (!hasAudio) return;

    if (_isSystem) {
      await _playSystem();
      return;
    }

    if (state.value == ChiptunePlaybackState.paused && _handle != null) {
      await _acquirePlaybackRuntimeLocks();
      SoLoud.instance.setPause(_handle!, false);
      state.value = ChiptunePlaybackState.playing;
      _updateNotificationForResume();
      _updateMediaControls(
        _module?.title.isNotEmpty == true ? _module!.title : notificationTitle,
        MediaPlaybackStatus.playing,
        duration: _totalDuration > Duration.zero ? _totalDuration : null,
        hasNext: onNext != null,
      );
      if (!_isNative) await _feed();
      _startFeed();
      return;
    }

    if (_isNative) {
      await _playNative();
      return;
    }

    await _ensureInit();
    await _renderWorker.stop();
    _stopInternal();
    await _acquirePlaybackRuntimeLocks();

    _elapsedBase = Duration.zero;
    _ended = false;
    _nearEndFired = false;
    await _renderWorker.start(
      module: _worklet!,
      sampleRate: sampleRate,
      looping: _looping,
      volume: _volume,
      chunkFrames: _chunkFrames,
    );
    _renderWorker.setStereoWidth(_stereoWidth);
    _renderWorker.setInterpolation(_interpolation.index);
    _renderWorker.setPreAmp(_preAmp);
    _renderWorker.setAmigaFilter(_amigaFilter.index);
    _renderWorker.setRampStep(_rampStep);
    _renderWorker.setModSeparation(_modSeparation);

    _stream = SoLoud.instance.setBufferStream(
      sampleRate: sampleRate,
      channels: Channels.stereo,
      format: BufferType.f32le,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0,
      maxBufferSizeDuration: const Duration(seconds: 30),
    );

    // Pre-fill before starting so playback begins instantly.
    await _feed();
    _handle = SoLoud.instance.play(_stream!, volume: 1);
    state.value = ChiptunePlaybackState.playing;
    _startFeed();
    _updateMediaControls(
      _module?.title.isNotEmpty == true ? _module!.title : notificationTitle,
      MediaPlaybackStatus.playing,
      duration: _totalDuration > Duration.zero ? _totalDuration : null,
      hasNext: onNext != null,
    );
  }

  /// Starts (or resumes) system-codec playback. Nothing is rendered locally, so
  /// this only arms the runtime locks, notification and media controls — the
  /// native player pushes position/end events on its own.
  Future<void> _playSystem() async {
    final resuming = state.value == ChiptunePlaybackState.paused;
    await _acquirePlaybackRuntimeLocks();
    final system = SystemAudioPlayer.instance;
    if (!resuming) {
      _elapsedBase = Duration.zero;
      _ended = false;
      _nearEndFired = false;
      _lastElapsedUpdateAt = null;
    }
    await system.setVolume(_volume);
    await system.setLooping(_looping);
    await system.play();
    state.value = ChiptunePlaybackState.playing;
    if (resuming) _updateNotificationForResume();
    _updateMediaControls(
      notificationTitle,
      MediaPlaybackStatus.playing,
      duration: _totalDuration > Duration.zero ? _totalDuration : null,
      hasNext: onNext != null,
    );
  }

  Future<void> _playNative() async {
    final source = _nativeSource;
    if (source == null) return;
    await _ensureInit();
    _stopInternal();
    await _acquirePlaybackRuntimeLocks();

    _elapsedBase = Duration.zero;
    _ended = false;
    _nearEndFired = false;
    // Native decode plays the source directly; volume is applied at the handle
    // (unlike the module path, where the mixer applies it and the stream plays
    // at unity gain).
    _handle = SoLoud.instance.play(source, volume: _volume, looping: _looping);
    state.value = ChiptunePlaybackState.playing;
    _startFeed();
    _updateMediaControls(
      notificationTitle,
      MediaPlaybackStatus.playing,
      duration: _totalDuration > Duration.zero ? _totalDuration : null,
      hasNext: onNext != null,
    );
  }

  void pause() {
    if (state.value != ChiptunePlaybackState.playing) return;
    if (_isSystem) {
      unawaited(SystemAudioPlayer.instance.pause());
      _updateNotificationForPause();
      state.value = ChiptunePlaybackState.paused;
      _updateMediaControls(notificationTitle, MediaPlaybackStatus.paused);
      return;
    }
    if (_handle == null) return;
    SoLoud.instance.setPause(_handle!, true);
    _feedTimer?.cancel();
    _feedTimer = null;
    _updateNotificationForPause();
    state.value = ChiptunePlaybackState.paused;
    _updateMediaControls(
      _module?.title.isNotEmpty == true ? _module!.title : notificationTitle,
      MediaPlaybackStatus.paused,
    );
  }

  void stop() {
    _stopInternal();
    _releasePlaybackRuntimeLocks();
    state.value = ChiptunePlaybackState.stopped;
    position.value = const SongPosition(0, 0);
    _elapsedBase = Duration.zero;
    elapsed.value = Duration.zero;
    final mod = _module;
    if (mod != null) {
      channelActivity.value = List<bool>.filled(mod.channels, false);
    }
    unawaited(MediaControlsService.instance.clear());
  }

  /// Seeks to an order/row and keeps playing if currently active.
  void seek(int order, int row) {
    if (_worklet == null) return;
    final mod = _module;
    // Clamp to valid bounds — the slider's last position can map one order past
    // the end, which would crash the mixer's pattern lookup.
    if (mod != null && mod.sequence.isNotEmpty) {
      order = order.clamp(0, mod.sequence.length - 1);
      final patIdx = mod.sequence[order];
      final rowCount = (patIdx >= 0 && patIdx < mod.patterns.length)
          ? mod.patterns[patIdx].rows.length
          : 0;
      row = rowCount > 0 ? row.clamp(0, rowCount - 1) : 0;
    }
    final wasPlaying = state.value == ChiptunePlaybackState.playing;
    _renderWorker.seek(order, row);
    if (_stream != null) {
      SoLoud.instance.resetBufferStream(_stream!);
    }
    // The stream's consumed-time timer restarts at zero after the reset, so
    // anchor the elapsed read-out to the seek target's song time.
    _elapsedBase = mod != null ? songTimeAt(mod, order, row) : Duration.zero;
    elapsed.value = _elapsedBase;
    position.value = SongPosition(order, row);
    if (wasPlaying) {
      unawaited(_feed());
    }
  }

  /// Seeks native audio to an absolute position (no-op for tracker modules,
  /// which seek by order/row via [seek]).
  void seekTo(Duration pos) {
    if (!_isSystem && (!_isNative || _nativeSource == null)) return;
    Duration target = pos < Duration.zero ? Duration.zero : pos;
    if (_totalDuration > Duration.zero && target > _totalDuration) {
      target = _totalDuration;
    }
    if (_isSystem) {
      unawaited(SystemAudioPlayer.instance.seek(target));
    } else if (_handle != null) {
      SoLoud.instance.seek(_handle!, target);
    }
    _elapsedBase = target;
    elapsed.value = target;
    // Re-arm the near-end prefetch when seeking back before the lead point.
    if (_totalDuration > Duration.zero &&
        target < _totalDuration - _prefetchLead) {
      _nearEndFired = false;
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_isSystem) {
      unawaited(SystemAudioPlayer.instance.setVolume(_volume));
    } else if (_isNative) {
      if (_handle != null) SoLoud.instance.setVolume(_handle!, _volume);
    } else {
      _renderWorker.setVolume(_volume);
    }
  }

  void setStereoWidth(double stereoWidth) {
    _stereoWidth = stereoWidth.clamp(0.0, 1.0);
    if (!isPlainAudio) {
      _renderWorker.setStereoWidth(_stereoWidth);
    }
  }

  void setInterpolation(ChiptuneInterpolation mode) {
    _interpolation = mode;
    if (!isPlainAudio) {
      _renderWorker.setInterpolation(mode.index);
    }
  }

  void setPreAmp(double value) {
    _preAmp = value;
    if (!isPlainAudio) {
      _renderWorker.setPreAmp(value);
    }
  }

  void setAmigaFilter(ChiptuneAmigaFilter mode) {
    _amigaFilter = mode;
    if (!isPlainAudio) {
      _renderWorker.setAmigaFilter(mode.index);
    }
  }

  void setRampStep(double value) {
    _rampStep = value;
    if (!isPlainAudio) {
      _renderWorker.setRampStep(value);
    }
  }

  void setModSeparation(double value) {
    _modSeparation = value;
    if (!isPlainAudio) {
      _renderWorker.setModSeparation(value);
    }
  }

  void setSpeed(int speed) {
    if (isPlainAudio) return;
    _renderWorker.setSpeed(speed);
  }

  void setLooping(bool looping) {
    _looping = looping;
    if (_isSystem) {
      unawaited(SystemAudioPlayer.instance.setLooping(looping));
    } else if (_isNative) {
      if (_handle != null) SoLoud.instance.setLooping(_handle!, looping);
    } else {
      _renderWorker.setLooping(looping);
    }
  }

  void setInitialDeviceId(int? deviceId) {
    _savedDeviceId = deviceId;
  }

  void setOutputDevice(PlaybackDevice? device) {
    _savedDeviceId = device?.id;
    if (SoLoud.instance.isInitialized) {
      try {
        SoLoud.instance.changeDevice(newDevice: device);
      } catch (e) {
        debugPrint('$_logPrefix Error changing output device: $e');
      }
    }
  }

  void _startFeed() {
    _feedTimer?.cancel();
    _scheduleFeedLoop();
  }

  void _scheduleFeedLoop() {
    if (state.value != ChiptunePlaybackState.playing) return;
    scheduleMicrotask(() async {
      await _feed();
      if (state.value == ChiptunePlaybackState.playing) {
        _feedTimer = Timer(_feedInterval, _scheduleFeedLoop);
      } else {
        _feedTimer = null;
      }
    });
  }

  Future<void> _feed() async {
    if (_feedInProgress) return;
    _feedInProgress = true;

    if (_isNative) {
      try {
        _nativeTick();
      } finally {
        _feedInProgress = false;
      }
      return;
    }

    final stream = _stream;
    if (stream == null) {
      _feedInProgress = false;
      return;
    }

    try {
      final DateTime now = DateTime.now();
      if (_uiUpdatesEnabled && _handle != null) {
        final DateTime? last = _lastElapsedUpdateAt;
        if (last == null || now.difference(last) >= _elapsedUpdateInterval) {
          _lastElapsedUpdateAt = now;
          elapsed.value =
              _elapsedBase + SoLoud.instance.getStreamTimeConsumed(stream);
        }
      }

      // Computed independently of the UI-throttled elapsed read-out so it also
      // works in the background. For songs shorter than the lead the threshold
      // is <= 0, so the prefetch fires as soon as playback starts.
      if (!_nearEndFired &&
          !_looping &&
          onNearEnd != null &&
          _handle != null &&
          _totalDuration > Duration.zero) {
        final Duration playbackTime =
            _elapsedBase + SoLoud.instance.getStreamTimeConsumed(stream);
        if (playbackTime >= _totalDuration - _prefetchLead) {
          _nearEndFired = true;
          onNearEnd!.call();
        }
      }

      _maybePushNotificationUpdate(now);

      if (_rendererEnded) {
        if (_stream != null) {
          try {
            SoLoud.instance.setDataIsEnded(_stream!);
          } catch (_) {}
        }
        final handle = _handle;
        if (handle == null || !SoLoud.instance.getIsValidVoiceHandle(handle)) {
          _ended = true;
        }
      }

      if (_ended) {
        _onSongEnded();
        return;
      }

      if (!_rendererEnded) {
        final int targetBytes = (sampleRate * _bufferAheadSeconds * 2 * 4)
            .toInt(); // stereo f32
        final int chunkBytes = _chunkFrames * 2 * Float32List.bytesPerElement;
        final int maxIterations = ((targetBytes / chunkBytes).ceil() + 8)
            .clamp(8, 96)
            .toInt();
        int guard = 0;
        while (!_ended && guard < maxIterations) {
          int buffered;
          try {
            buffered = SoLoud.instance.getBufferSize(stream);
          } catch (_) {
            buffered = targetBytes; // stop topping up if query fails
          }
          if (buffered >= targetBytes) break;

          final Float32List chunk = await _renderWorker.render(_chunkFrames);
          if (chunk.isEmpty) break;
          // The stream can be disposed/replaced (stop, seek, loadModule, play
          // restart) while this render await is pending. Touching the old native
          // source after that is a use-after-free that can hang the app, so bail
          // if it is no longer the current stream.
          if (!identical(_stream, stream)) break;

          try {
            SoLoud.instance.addAudioDataStream(
              stream,
              chunk.buffer.asUint8List(),
            );
          } catch (e) {
            debugPrint('$_logPrefix addAudioDataStream failed: $e');
            break;
          }
          guard++;
        }
      }
    } finally {
      _feedInProgress = false;
    }
  }

  /// Polls native-decode playback: updates the elapsed read-out, fires the
  /// near-end prefetch, and detects the end (the voice handle goes invalid when
  /// a non-looping source finishes).
  void _nativeTick() {
    final handle = _handle;
    if (handle == null) return;

    if (!_looping && !SoLoud.instance.getIsValidVoiceHandle(handle)) {
      _ended = true;
      _onSongEnded();
      return;
    }

    final DateTime now = DateTime.now();
    final Duration pos = SoLoud.instance.getPosition(handle);

    if (_uiUpdatesEnabled) {
      final DateTime? last = _lastElapsedUpdateAt;
      if (last == null || now.difference(last) >= _elapsedUpdateInterval) {
        _lastElapsedUpdateAt = now;
        elapsed.value = pos;
      }
    }

    if (!_nearEndFired &&
        !_looping &&
        onNearEnd != null &&
        _totalDuration > Duration.zero &&
        pos >= _totalDuration - _prefetchLead) {
      _nearEndFired = true;
      onNearEnd!.call();
    }

    _maybePushNotificationUpdate(now);
  }

  /// Throttled (30 s) refresh of the background-playback notification text.
  void _maybePushNotificationUpdate(DateTime now) {
    if (_foregroundRuntimeLease == null ||
        state.value != ChiptunePlaybackState.playing) {
      return;
    }
    if (_lastNotificationUpdateAt != null &&
        now.difference(_lastNotificationUpdateAt!) <
            const Duration(seconds: 30)) {
      return;
    }
    _lastNotificationUpdateAt = now;
    notificationText = formatTime(elapsed.value, _totalDuration);
    final actions = <String>['pause', 'stop'];
    if (onNext != null) actions.add('next');
    unawaited(
      _foregroundRuntimeLease!.update(
        title: notificationTitle,
        text: notificationText,
        actions: actions,
      ),
    );
    _updateMediaPosition(elapsed.value);
  }

  static String formatTime(Duration elapsed, Duration total) {
    final e =
        '${_twoDigits(elapsed.inMinutes.remainder(60))}:${_twoDigits(elapsed.inSeconds.remainder(60))}';
    if (total == Duration.zero) return e;
    return '$e / ${_twoDigits(total.inMinutes.remainder(60))}:${_twoDigits(total.inSeconds.remainder(60))}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  void _onSongEnded() {
    _feedTimer?.cancel();
    _feedTimer = null;
    if (_stream != null) {
      SoLoud.instance.setDataIsEnded(_stream!);
    }
    state.value = ChiptunePlaybackState.stopped;
    notificationText = formatTime(Duration.zero, _totalDuration);
    unawaited(MediaControlsService.instance.clear());
    // Keep the wakelock + foreground service alive across an auto-advance so the
    // next-track fetch (potentially slow, in the background) is not killed. The
    // subsequent play() reuses the still-held leases; if the page decides not to
    // advance (or the fetch fails) it calls stop() to release them.
    if (!(shouldKeepPlaybackAlive?.call() ?? false)) {
      _releasePlaybackRuntimeLocks();
    }
    onEnded?.call();
  }

  Future<void> _ensureInit() async {
    PlaybackDevice? savedDevice;
    final savedId = _savedDeviceId;
    if (savedId != null) {
      try {
        final devices = SoLoud.instance.listPlaybackDevices();
        for (final d in devices) {
          if (d.id == savedId) {
            savedDevice = d;
            break;
          }
        }
      } catch (e) {
        debugPrint('$_logPrefix Error listing devices during init: $e');
      }
    }

    if (!SoLoud.instance.isInitialized) {
      final lowLatencyVal = await DatabaseService.instance.getSetting(
        '_app',
        'low_latency_audio',
      );
      final lowLatency = lowLatencyVal != 'false';
      await SoLoud.instance.init(device: savedDevice, lowLatency: lowLatency);
    } else if (savedDevice != null) {
      try {
        SoLoud.instance.changeDevice(newDevice: savedDevice);
      } catch (e) {
        debugPrint('$_logPrefix Error changing device during init: $e');
      }
    }
  }

  void _stopInternal() {
    _feedTimer?.cancel();
    _feedTimer = null;
    _feedInProgress = false;
    _ended = false;
    _rendererEnded = false;
    _lastUiUpdateAt = null;
    _lastElapsedUpdateAt = null;
    _lastNotificationUpdateAt = null;
    if (_isSystem) {
      // Pause + rewind; the source stays prepared so a following play() restarts
      // it without another load.
      unawaited(SystemAudioPlayer.instance.stop());
      systemSpectrum.value = null;
    }
    unawaited(_renderWorker.stop());
    final handle = _handle;
    if (handle != null) {
      SoLoud.instance.stop(handle);
      _handle = null;
    }
    final stream = _stream;
    if (stream != null) {
      SoLoud.instance.disposeSource(stream);
      _stream = null;
    }
    // Note: runtime locks (wakelock + foreground service) are intentionally NOT
    // released here. _stopInternal runs during song→song transitions (play() and
    // loadModule()) where the locks must stay held. They are released explicitly
    // at genuine stop points: stop(), dispose(), and _onSongEnded (no auto-advance).
  }

  Future<void> _acquirePlaybackRuntimeLocks() async {
    _partialWakeLock ??= await PowerWakeLockService.acquirePartial();
    if (_foregroundRuntimeLease == null) {
      final List<String> actions = ['pause', 'stop'];
      if (onNext != null) {
        actions.add('next');
      }
      _foregroundRuntimeLease = await ForegroundRuntimeService.acquire(
        title: notificationTitle,
        text: notificationText,
        actions: actions,
      );
      ForegroundRuntimeService.addActionListener(_handleNotificationAction);
    }
  }

  void _releasePlaybackRuntimeLocks() {
    if (_foregroundRuntimeLease != null) {
      ForegroundRuntimeService.removeActionListener(_handleNotificationAction);
      final foregroundLease = _foregroundRuntimeLease;
      _foregroundRuntimeLease = null;
      if (foregroundLease != null) {
        unawaited(foregroundLease.release());
      }
    }
    final partialLease = _partialWakeLock;
    _partialWakeLock = null;
    if (partialLease != null) {
      unawaited(partialLease.release());
    }
  }

  void _updateNotificationForPause() {
    final lease = _foregroundRuntimeLease;
    if (lease == null) return;
    unawaited(
      lease.update(
        title: notificationTitle,
        text: notificationText,
        actions: ['play', 'stop'],
      ),
    );
  }

  void _updateNotificationForResume() {
    final lease = _foregroundRuntimeLease;
    if (lease == null) return;
    final actions = <String>['pause', 'stop'];
    if (onNext != null) actions.add('next');
    unawaited(
      lease.update(
        title: notificationTitle,
        text: notificationText,
        actions: actions,
      ),
    );
  }

  VoidCallback? onPrevious;
  StreamSubscription<MediaButton>? _mediaButtonSub;

  void _initMediaControls() {
    _mediaButtonSub ??= MediaControlsService.instance.buttonEvents.listen((
      button,
    ) {
      switch (button) {
        case MediaButton.play:
          unawaited(play());
          break;
        case MediaButton.pause:
          pause();
          break;
        case MediaButton.stop:
          stop();
          break;
        case MediaButton.next:
          onNext?.call();
          break;
        case MediaButton.previous:
          onPrevious?.call();
          break;
      }
    });
  }

  void _updateMediaControls(
    String title,
    MediaPlaybackStatus status, {
    Duration? duration,
    bool hasNext = false,
  }) {
    _initMediaControls();
    unawaited(
      MediaControlsService.instance.updateMetadata(
        MediaMetadata(
          title: title,
          duration: duration,
          supportedButtons: [
            MediaButton.play,
            MediaButton.pause,
            MediaButton.stop,
            if (hasNext) MediaButton.next,
          ],
        ),
      ),
    );
    unawaited(MediaControlsService.instance.updatePlaybackStatus(status));
  }

  void _updateMediaPosition(Duration position) {
    unawaited(MediaControlsService.instance.updatePosition(position));
  }

  void _handleNotificationAction(String action) {
    switch (action) {
      case 'play':
        unawaited(play());
        break;
      case 'pause':
        pause();
        break;
      case 'stop':
        stop();
        break;
      case 'next':
        onNext?.call();
        break;
    }
  }

  void dispose() {
    _stopInternal();
    _disposeNativeSource();
    _releaseSystemSource();
    _releasePlaybackRuntimeLocks();
    _systemSubscription?.cancel();
    _systemSubscription = null;
    _rowSubscription?.cancel();
    _endedSubscription?.cancel();
    _mediaButtonSub?.cancel();
    _mediaButtonSub = null;
    unawaited(_renderWorker.dispose());
    state.dispose();
    position.dispose();
    channelActivity.dispose();
    elapsed.dispose();
    systemSpectrum.dispose();
  }
}

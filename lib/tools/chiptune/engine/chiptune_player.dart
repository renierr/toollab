import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/foreground_runtime_service.dart';
import '../../../services/power_wake_lock_service.dart';
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
  bool _uiUpdatesEnabled = true;
  Duration _feedInterval = _feedIntervalForeground;
  Duration _uiUpdateInterval = _uiUpdateIntervalForeground;
  Duration _elapsedUpdateInterval = _elapsedUpdateIntervalForeground;
  bool _ended = false;
  double _volume = 0.7;
  bool _looping = false;

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

  /// Fired once when a non-looping song reaches its end.
  VoidCallback? onEnded;

  /// Fired when 'next' is clicked in the foreground service notification.
  VoidCallback? onNext;

  ModuleFile? get module => _module;
  bool get isPlaying => state.value == ChiptunePlaybackState.playing;
  bool get hasModule => _worklet != null;

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
      _ended = true;
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
    _module = mod;
    _worklet = serializeModuleForWorklet(mod);
    _totalDuration = estimateSongDuration(mod);
    _elapsedBase = Duration.zero;
    channelActivity.value = List<bool>.filled(mod.channels, false);
    position.value = const SongPosition(0, 0);
    elapsed.value = Duration.zero;
  }

  Future<void> play() async {
    if (_worklet == null) return;

    if (state.value == ChiptunePlaybackState.paused && _handle != null) {
      await _acquirePlaybackRuntimeLocks();
      SoLoud.instance.setPause(_handle!, false);
      state.value = ChiptunePlaybackState.playing;
      _updateNotificationForResume();
      await _feed();
      _startFeed();
      return;
    }

    await _ensureInit();
    await _renderWorker.stop();
    _stopInternal();
    await _acquirePlaybackRuntimeLocks();

    _elapsedBase = Duration.zero;
    _ended = false;
    await _renderWorker.start(
      module: _worklet!,
      sampleRate: sampleRate,
      looping: _looping,
      volume: _volume,
      chunkFrames: _chunkFrames,
    );

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
  }

  void pause() {
    if (state.value != ChiptunePlaybackState.playing || _handle == null) return;
    SoLoud.instance.setPause(_handle!, true);
    _feedTimer?.cancel();
    _feedTimer = null;
    _updateNotificationForPause();
    state.value = ChiptunePlaybackState.paused;
  }

  void stop() {
    _stopInternal();
    state.value = ChiptunePlaybackState.stopped;
    position.value = const SongPosition(0, 0);
    _elapsedBase = Duration.zero;
    elapsed.value = Duration.zero;
    final mod = _module;
    if (mod != null) {
      channelActivity.value = List<bool>.filled(mod.channels, false);
    }
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

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _renderWorker.setVolume(_volume);
  }

  void setSpeed(int speed) => _renderWorker.setSpeed(speed);

  void setLooping(bool looping) {
    _looping = looping;
    _renderWorker.setLooping(looping);
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

    final stream = _stream;
    if (stream == null) {
      _feedInProgress = false;
      return;
    }

    try {
      if (_uiUpdatesEnabled && _handle != null) {
        final DateTime now = DateTime.now();
        final DateTime? last = _lastElapsedUpdateAt;
        if (last == null || now.difference(last) >= _elapsedUpdateInterval) {
          _lastElapsedUpdateAt = now;
          elapsed.value =
              _elapsedBase + SoLoud.instance.getStreamTimeConsumed(stream);
        }
      }

      if (_ended) {
        _onSongEnded();
        return;
      }

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
    } finally {
      _feedInProgress = false;
    }
  }

  void _onSongEnded() {
    _feedTimer?.cancel();
    _feedTimer = null;
    if (_stream != null) {
      SoLoud.instance.setDataIsEnded(_stream!);
    }
    state.value = ChiptunePlaybackState.stopped;
    _releasePlaybackRuntimeLocks();
    onEnded?.call();
  }

  Future<void> _ensureInit() async {
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
  }

  void _stopInternal() {
    _feedTimer?.cancel();
    _feedTimer = null;
    _feedInProgress = false;
    _lastUiUpdateAt = null;
    _lastElapsedUpdateAt = null;
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
    _releasePlaybackRuntimeLocks();
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
    _rowSubscription?.cancel();
    _endedSubscription?.cancel();
    unawaited(_renderWorker.dispose());
    state.dispose();
    position.dispose();
    channelActivity.dispose();
    elapsed.dispose();
  }
}

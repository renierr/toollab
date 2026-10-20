import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import '../../helpers/wav_pcm16_encoder.dart';
import '../../services/background_work_lease.dart';
import '../../services/database_service.dart';
import 'audio/db_scale.dart';
import 'config.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

/// What the recorder needs from the owner of the microphone.
abstract interface class SleepCaptureHost {
  int get sampleRate;

  /// Starts the mic if needed; false when it cannot run.
  Future<bool> ensureMicRunning();

  /// Turns off processing effects and gain and restarts capture; false when
  /// the mic cannot run.
  Future<bool> prepareFaithfulCapture();

  /// Puts back the user's clip length limit after a session and releases the
  /// mic when nothing else needs it any more.
  Future<void> releaseCapture();

  void startCapture();

  Float32List stopCapture();
}

/// Records a night in 15 s chunks, keeping only chunks above the threshold.
class SleepRecorder extends ChangeNotifier {
  SleepRecorder(this._host, {this._syncSessions});

  static const _logPrefix = '[SleepRecorder]';
  static const _chunkLength = Duration(seconds: 15);
  static const _kThreshold = 'sf_sleep_threshold';
  static const _kAdaptive = 'sf_sleep_adaptive';
  static const _kDuration = 'sf_sleep_duration';
  static const double minThreshold = 0.0005;
  static const double maxThreshold = 0.2;
  static const int minDurationMinutes = 15;
  static const int maxDurationMinutes = 16 * 60;

  final SleepCaptureHost _host;
  final Future<void> Function()? _syncSessions;

  bool _active = false;
  bool _finishing = false;
  bool _micUnavailable = false;
  int _durationMinutes = 480;
  double _threshold = 0.005;
  bool _adaptive = false;
  double _lastMaxAbs = 0;
  DateTime? _start;
  DateTime? _chunkStart;
  DateTime? _lastEvent;
  double _ambientMax = 0;
  String? _sessionDir;
  final List<SleepEvent> _events = [];
  Timer? _timeout;
  Timer? _chunkTimer;
  BackgroundWorkLease? _work;
  String _notificationTitle = 'Sleep sound recorder';
  String _notificationText = 'Recording sleep sounds';
  String _finishingText = 'Saving and syncing the session';
  String Function(int count) _savedChunksText = (count) => '$count';

  bool get active => _active;

  /// The stopped session is still being analyzed and synced.
  bool get finishing => _finishing;
  bool get micUnavailable => _micUnavailable;
  int get durationMinutes => _durationMinutes;
  double get threshold => _threshold;
  bool get adaptive => _adaptive;
  double get lastMaxAbs => _lastMaxAbs;
  DateTime? get lastEvent => _lastEvent;
  List<SleepEvent> get events => List.unmodifiable(_events);
  Duration get elapsed =>
      _start == null ? Duration.zero : DateTime.now().difference(_start!);
  DateTime? get endsAt => _start?.add(Duration(minutes: _durationMinutes));

  Future<void> loadSettings() async {
    final db = DatabaseService.instance;
    final id = SoundFinderTool.config.id;
    _threshold =
        double.tryParse(await db.getSetting(id, _kThreshold) ?? '') ?? 0.005;
    _adaptive = await db.getSetting(id, _kAdaptive) == 'true';
    final duration = int.tryParse(await db.getSetting(id, _kDuration) ?? '');
    if (duration != null && !_active) {
      _durationMinutes = duration.clamp(minDurationMinutes, maxDurationMinutes);
    }
  }

  void _save(String key, String value) => DatabaseService.instance.setSetting(
    SoundFinderTool.config.id,
    key,
    value,
  );

  void setNotificationText({
    required String title,
    required String text,
    required String finishing,
    required String Function(int count) savedChunks,
  }) {
    _notificationTitle = title;
    _notificationText = text;
    _finishingText = finishing;
    _savedChunksText = savedChunks;
  }

  void setDurationMinutes(int minutes) {
    if (_active) return;
    _durationMinutes = minutes.clamp(minDurationMinutes, maxDurationMinutes);
    _save(_kDuration, _durationMinutes.toString());
    notifyListeners();
  }

  void setThreshold(double value) {
    _threshold = value.clamp(minThreshold, maxThreshold);
    _save(_kThreshold, _threshold.toStringAsFixed(5));
    notifyListeners();
  }

  void setAdaptive(bool value) {
    _adaptive = value;
    _save(_kAdaptive, value.toString());
    notifyListeners();
  }

  Future<void> calibrate() async {
    if (_active || !await _host.ensureMicRunning()) return;
    _host.startCapture();
    await Future.delayed(const Duration(seconds: 3));
    final maxAbs = _peak(_host.stopCapture());
    if (maxAbs > 0) setThreshold(maxAbs * 2);
  }

  Future<void> start() async {
    if (_active) return;
    _micUnavailable = false;
    if (!await _host.prepareFaithfulCapture()) {
      _micUnavailable = true;
      notifyListeners();
      return;
    }

    _active = true;
    final now = DateTime.now();
    _start = now;
    _events.clear();
    _lastEvent = null;
    _ambientMax = 0;
    _sessionDir = await SleepSessionStore.sessionPath('session-${_stamp(now)}');
    await Directory(_sessionDir!).create(recursive: true);

    // Keep CPU awake and run as a foreground service with a notification so
    // Android does not suspend the mic capture; the page lets the screen off.
    _work = await BackgroundWorkLease.acquire(
      title: _notificationTitle,
      text: _notificationText,
      logPrefix: 'SoundFinderSleep',
      actions: const ['stop'],
      chronometerSinceMs: now.millisecondsSinceEpoch,
    );
    _work!.addActionListener((action) {
      if (action == 'stop') unawaited(stop());
    });

    _timeout = Timer(
      Duration(minutes: _durationMinutes),
      () => unawaited(stop()),
    );
    _chunkStart = DateTime.now();
    _host.startCapture();
    _scheduleChunk();
    notifyListeners();
  }

  void _scheduleChunk() {
    _chunkTimer?.cancel();
    _chunkTimer = Timer(_chunkLength, () async {
      if (!_active) return;
      await _processChunk(_chunkStart ?? DateTime.now());
      if (_active) {
        _chunkStart = DateTime.now();
        _host.startCapture();
        _scheduleChunk();
      }
    });
  }

  Future<void> _processChunk(DateTime chunkStart) async {
    final samples = _host.stopCapture();
    final endedAt = DateTime.now();
    if (samples.isEmpty) {
      errorLog('$_logPrefix chunk empty');
      return;
    }
    final maxAbs = _peak(samples);
    _lastMaxAbs = maxAbs;
    if (kDebugMode) {
      debugLog(
        '$_logPrefix chunk samples=${samples.length} maxAbs=$maxAbs '
        'threshold=$_threshold',
      );
    }
    // Adaptive threshold follows the ambient floor of the quiet chunks only.
    if (_adaptive) {
      if (maxAbs < _threshold && maxAbs > _ambientMax) _ambientMax = maxAbs;
      if (_ambientMax > 0) {
        _threshold = (_ambientMax * 2).clamp(minThreshold, maxThreshold);
      }
    }
    if (maxAbs < _threshold) return;

    final dirPath = _sessionDir ?? (await SleepSessionStore.root()).path;
    final fileName = 'chunk-${_stamp(endedAt)}.wav';
    await File('$dirPath/$fileName').writeAsBytes(
      WavPcm16Encoder.encode(
        samples,
        frames: samples.length,
        sampleRate: _host.sampleRate,
        channels: 1,
      ),
    );
    _lastEvent = DateTime.now();
    _events.add(
      SleepEvent(
        fileName: fileName,
        startedAt: chunkStart,
        endedAt: endedAt,
        peakAmplitude: maxAbs,
        classification: _levelBucket(maxAbs),
      ),
    );
    unawaited(
      _work?.update(_savedChunksText(_events.length)) ?? Future<void>.value(),
    );
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    _timeout?.cancel();
    _timeout = null;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    final sessionStart = _start ?? DateTime.now();
    await _processChunk(_chunkStart ?? DateTime.now());
    _start = null;
    final work = _work;
    _work = null;
    work?.removeActionListener();

    final dir = _sessionDir;
    _sessionDir = null;
    SleepSessionData? data;
    if (dir != null) {
      data = SleepSessionData(
        path: dir,
        startedAt: sessionStart,
        endedAt: DateTime.now(),
        targetMinutes: _durationMinutes,
        threshold: _threshold,
        adaptiveThreshold: _adaptive,
        events: List.of(_events),
      );
      await data.save();
      SleepSessionStore.notifyChanged();
    }
    await _host.releaseCapture();
    _finishing = true;
    notifyListeners();
    unawaited(_finish(data, work));
  }

  /// Analyzes and syncs the stopped session under a foreground lease of its
  /// own, so both complete even when the app is closed right after stopping.
  Future<void> _finish(
    SleepSessionData? data,
    BackgroundWorkLease? recording,
  ) async {
    // Acquired before the recording lease goes, so the notification swaps
    // over to one without the now dead stop action instead of flickering.
    final work = await BackgroundWorkLease.acquire(
      title: _notificationTitle,
      text: _finishingText,
      logPrefix: 'SoundFinderSleep',
    );
    await recording?.release();
    try {
      final session = data == null
          ? null
          : await SleepSessionStore.byId(data.id);
      if (session != null) await SleepSessionStore.analyze(session);
      await _syncSessions?.call();
    } catch (e) {
      errorLog('$_logPrefix finishing session failed: $e');
    } finally {
      await work.release();
      _finishing = false;
      notifyListeners();
    }
  }

  static double _peak(Float32List samples) {
    var maxAbs = 0.0;
    for (final s in samples) {
      final a = s.abs();
      if (a > maxAbs) maxAbs = a;
    }
    return maxAbs;
  }

  static String _levelBucket(double peak) {
    final db = ampToDb(peak);
    if (db >= -10) return 'loud';
    if (db >= -25) return 'sound';
    return 'faint';
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _chunkTimer?.cancel();
    super.dispose();
  }
}

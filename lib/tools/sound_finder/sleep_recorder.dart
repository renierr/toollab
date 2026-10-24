import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import '../../helpers/wav_pcm16_encoder.dart';
import '../../services/background_work_lease.dart';
import '../../services/database_service.dart';
import '../../services/foreground_runtime_service.dart';
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
  static const _kGrace = 'sf_sleep_grace';
  static const double minThreshold = 0.0005;
  static const double maxThreshold = 0.2;
  static const int minDurationMinutes = 15;
  static const int maxDurationMinutes = 16 * 60;
  static const int maxGraceMinutes = 120;

  final SleepCaptureHost _host;
  final Future<void> Function()? _syncSessions;

  bool _active = false;
  bool _starting = false;
  bool _finishing = false;
  bool _micUnavailable = false;
  bool _startFailed = false;
  // Bumped on start and stop so a stale await cannot touch a newer session.
  int _session = 0;
  int _durationMinutes = 480;
  int _graceMinutes = 5;
  double _threshold = 0.005;
  bool _adaptive = false;
  double _lastMaxAbs = 0;
  DateTime? _recordsAt;
  DateTime? _start;
  DateTime? _chunkStart;
  DateTime? _lastEvent;
  double _ambientMax = 0;
  String? _sessionDir;
  final List<SleepEvent> _events = [];
  Timer? _graceTimer;
  Timer? _timeout;
  Timer? _chunkTimer;
  BackgroundWorkLease? _work;
  String _notificationTitle = 'Sleep sound recorder';
  String _notificationText = 'Recording sleep sounds';
  String Function(DateTime at) _waitingText = (at) => '$at';
  String _finishingText = 'Saving and syncing the session';
  String Function(int count) _savedChunksText = (count) => '$count';

  /// A session is running, in its grace period or recording.
  bool get active => _active;

  /// The session runs but the grace period has not passed yet.
  bool get waiting => _active && _start == null;

  /// The stopped session is still being analyzed and synced.
  bool get finishing => _finishing;
  bool get starting => _starting;
  bool get micUnavailable => _micUnavailable;
  bool get startFailed => _startFailed;
  int get durationMinutes => _durationMinutes;
  int get graceMinutes => _graceMinutes;
  double get threshold => _threshold;
  bool get adaptive => _adaptive;
  double get lastMaxAbs => _lastMaxAbs;
  DateTime? get lastEvent => _lastEvent;
  List<SleepEvent> get events => List.unmodifiable(_events);
  Duration get elapsed =>
      _start == null ? Duration.zero : DateTime.now().difference(_start!);
  DateTime? get recordsAt => _recordsAt;
  DateTime? get endsAt =>
      (_start ?? _recordsAt)?.add(Duration(minutes: _durationMinutes));

  Future<void> loadSettings() async {
    final db = DatabaseService.instance;
    final id = SoundFinderTool.config.id;
    _threshold =
        double.tryParse(await db.getSetting(id, _kThreshold) ?? '') ?? 0.005;
    _adaptive = await db.getSetting(id, _kAdaptive) == 'true';
    final duration = int.tryParse(await db.getSetting(id, _kDuration) ?? '');
    final grace = int.tryParse(await db.getSetting(id, _kGrace) ?? '');
    if (!_active) {
      if (duration != null) {
        _durationMinutes = duration.clamp(
          minDurationMinutes,
          maxDurationMinutes,
        );
      }
      if (grace != null) _graceMinutes = grace.clamp(0, maxGraceMinutes);
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
    required String Function(DateTime at) waiting,
    required String finishing,
    required String Function(int count) savedChunks,
  }) {
    _notificationTitle = title;
    _notificationText = text;
    _waitingText = waiting;
    _finishingText = finishing;
    _savedChunksText = savedChunks;
  }

  void setDurationMinutes(int minutes) {
    if (_active) return;
    _durationMinutes = minutes.clamp(minDurationMinutes, maxDurationMinutes);
    _save(_kDuration, _durationMinutes.toString());
    notifyListeners();
  }

  void setGraceMinutes(int minutes) {
    if (_active) return;
    _graceMinutes = minutes.clamp(0, maxGraceMinutes);
    _save(_kGrace, _graceMinutes.toString());
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
    if (_active || _starting) return;
    _starting = true;
    _micUnavailable = false;
    _startFailed = false;
    notifyListeners();
    try {
      await _prepareAndStart();
    } catch (e) {
      errorLog('$_logPrefix start: $e');
      _startFailed = true;
      if (waiting) await _abortStart();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> _prepareAndStart() async {
    if (!await _host.prepareFaithfulCapture()) {
      _micUnavailable = true;
      return;
    }

    final session = ++_session;
    _active = true;
    _start = null;
    _events.clear();
    _lastEvent = null;
    _ambientMax = 0;
    final grace = Duration(minutes: _graceMinutes);
    final recordsAt = DateTime.now().add(grace);
    _recordsAt = recordsAt;
    notifyListeners();

    // Keep CPU awake and run as a foreground service with a notification so
    // Android does not suspend the mic capture; the page lets the screen off.
    // Taken before the grace period: the mic must already be open while the
    // app is in the foreground, Android refuses to open it from background.
    final work = await BackgroundWorkLease.acquire(
      title: _notificationTitle,
      text: grace == Duration.zero
          ? _notificationText
          : _waitingText(recordsAt),
      logPrefix: 'SoundFinderSleep',
      actions: const ['stop'],
      // Microphone only: Android 15+ stops dataSync work after 6 h per 24 h,
      // which used to cut every long night short.
      types: const {ForegroundServiceType.microphone},
    );
    if (session != _session) {
      await work.release();
      return;
    }
    _work = work;
    work.addActionListener((action) {
      if (action == 'stop') unawaited(stop());
    });

    if (grace == Duration.zero) {
      await _beginRecording(session);
    } else {
      _graceTimer = Timer(grace, () => unawaited(_beginRecording(session)));
    }
  }

  /// Ends the grace period early and starts recording right away.
  Future<void> skipGrace() async {
    if (!waiting || _graceTimer == null) return;
    _graceTimer?.cancel();
    await _beginRecording(_session);
  }

  Future<void> _beginRecording(int session) async {
    _graceTimer = null;
    final now = DateTime.now();
    final (String, bool) folder;
    try {
      folder = await _createSessionDir(now);
    } catch (e) {
      errorLog('$_logPrefix session folder: $e');
      if (session == _session) await _failStart();
      return;
    }
    final (dir, created) = folder;
    if (session != _session || !waiting) {
      // Stopped meanwhile; a pre-existing folder may belong to a newer session.
      if (created) await _deleteDir(dir);
      return;
    }
    try {
      _host.startCapture();
    } catch (e) {
      errorLog('$_logPrefix start capture: $e');
      await _failStart();
      if (created) await _deleteDir(dir);
      return;
    }
    _start = now;
    _recordsAt = now;
    _sessionDir = dir;
    _timeout = Timer(
      Duration(minutes: _durationMinutes),
      () => unawaited(stop()),
    );
    _chunkStart = DateTime.now();
    _scheduleChunk();
    unawaited(
      _work?.update(
            _notificationText,
            minIntervalMs: 0,
            chronometerSinceMs: now.millisecondsSinceEpoch,
          ) ??
          Future<void>.value(),
    );
    notifyListeners();
  }

  /// Returns the folder path and whether this call created it.
  static Future<(String, bool)> _createSessionDir(DateTime now) async {
    final dir = Directory(
      await SleepSessionStore.sessionPath('session-${_stamp(now)}'),
    );
    final created = !await dir.exists();
    await dir.create(recursive: true);
    return (dir.path, created);
  }

  static Future<void> _deleteDir(String dir) async {
    try {
      await Directory(dir).delete(recursive: true);
    } catch (e) {
      errorLog('$_logPrefix delete empty session: $e');
    }
  }

  Future<void> _failStart() async {
    _startFailed = true;
    await _abortStart();
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
      _work?.update(
            _savedChunksText(_events.length),
            chronometerSinceMs: _start?.millisecondsSinceEpoch,
          ) ??
          Future<void>.value(),
    );
    notifyListeners();
    // Without this, a night the OS kills before stop() loses every peak and
    // time and comes back rebuilt from file names only.
    final start = _start;
    if (_sessionDir != null && start != null) {
      try {
        await _snapshot(_sessionDir!, start, endedAt).save(touch: false);
      } catch (e) {
        errorLog('$_logPrefix progress save: $e');
      }
    }
  }

  SleepSessionData _snapshot(String dir, DateTime start, DateTime end) =>
      SleepSessionData(
        path: dir,
        startedAt: start,
        endedAt: end,
        targetMinutes: _durationMinutes,
        threshold: _threshold,
        adaptiveThreshold: _adaptive,
        events: List.of(_events),
      );

  Future<void> stop() async {
    if (!_active) return;
    if (waiting) return _abortStart();
    _session++;
    _active = false;
    _recordsAt = null;
    _timeout?.cancel();
    _timeout = null;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    final sessionStart = _start ?? DateTime.now();
    // Every step below may throw; none may skip _finish, which frees the lease.
    try {
      await _processChunk(_chunkStart ?? DateTime.now());
    } catch (e) {
      errorLog('$_logPrefix last chunk: $e');
    }
    _start = null;
    final work = _work;
    _work = null;
    work?.removeActionListener();

    final dir = _sessionDir;
    _sessionDir = null;
    SleepSessionData? data;
    if (dir != null) {
      data = _snapshot(dir, sessionStart, DateTime.now());
      try {
        await data.save();
      } catch (e) {
        errorLog('$_logPrefix save session: $e');
      }
      SleepSessionStore.notifyChanged();
    }
    try {
      await _host.releaseCapture();
    } catch (e) {
      errorLog('$_logPrefix release capture: $e');
    }
    _finishing = true;
    notifyListeners();
    unawaited(_finish(data, work));
  }

  /// Nothing was recorded yet, so there is no session to save or sync.
  Future<void> _abortStart() async {
    _session++;
    _active = false;
    _recordsAt = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    final work = _work;
    _work = null;
    work?.removeActionListener();
    notifyListeners();
    try {
      await work?.release();
    } catch (e) {
      errorLog('$_logPrefix release lease: $e');
    }
    try {
      await _host.releaseCapture();
    } catch (e) {
      errorLog('$_logPrefix release capture: $e');
    }
  }

  /// Analyzes and syncs the stopped session under a foreground lease of its
  /// own, so both complete even when the app is closed right after stopping.
  Future<void> _finish(
    SleepSessionData? data,
    BackgroundWorkLease? recording,
  ) async {
    // Acquired before the recording lease goes, so the notification swaps
    // over to one without the now dead stop action instead of flickering.
    BackgroundWorkLease? work;
    try {
      work = await BackgroundWorkLease.acquire(
        title: _notificationTitle,
        text: _finishingText,
        logPrefix: 'SoundFinderSleep',
      );
      await recording?.release();
      recording = null;
      final session = data == null
          ? null
          : await SleepSessionStore.byId(data.id);
      if (session != null) await SleepSessionStore.analyze(session);
      await _syncSessions?.call();
    } catch (e) {
      errorLog('$_logPrefix finishing session failed: $e');
    } finally {
      _finishing = false;
      notifyListeners();
      for (final lease in [recording, work]) {
        try {
          await lease?.release();
        } catch (e) {
          errorLog('$_logPrefix release lease: $e');
        }
      }
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
    _graceTimer?.cancel();
    _timeout?.cancel();
    _chunkTimer?.cancel();
    super.dispose();
  }
}

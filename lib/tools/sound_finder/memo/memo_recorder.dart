import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import '../../../services/background_work_lease.dart';
import '../../../services/foreground_runtime_service.dart';
import 'memo_settings.dart';
import 'memo_store.dart';

enum MemoStatus { idle, starting, recording, paused, stopping }

enum MemoStartResult { ok, denied, failed, busy }

/// Live meter data, published at the poll rate without rebuilding the page.
class MemoLevels extends ChangeNotifier {
  static const int historyLength = 120;
  static const double floorDb = -60;

  final Float32List history = Float32List(historyLength);
  int _head = 0;
  double db = floorDb;
  double peakDb = floorDb;
  bool clipped = false;
  Duration elapsed = Duration.zero;

  /// Bars oldest to newest, 0..1.
  double bar(int i) => history[(_head + i) % historyLength];

  static double norm(double db) =>
      ((db - floorDb) / -floorDb).clamp(0.0, 1.0).toDouble();

  void _push(double currentDb, Duration time) {
    db = currentDb;
    if (currentDb > peakDb) peakDb = currentDb;
    if (currentDb >= -0.3) clipped = true;
    history[_head] = norm(currentDb);
    _head = (_head + 1) % historyLength;
    elapsed = time;
    notifyListeners();
  }

  void _tick(Duration time) {
    elapsed = time;
    notifyListeners();
  }

  void _reset() {
    history.fillRange(0, historyLength, 0);
    _head = 0;
    db = floorDb;
    peakDb = floorDb;
    clipped = false;
    elapsed = Duration.zero;
    notifyListeners();
  }

  void resetPeak() {
    peakDb = db;
    clipped = false;
    notifyListeners();
  }
}

/// Records memos straight to a lossless file through the platform encoder,
/// so capture never depends on the UI isolate keeping up.
class MemoRecorder extends ChangeNotifier {
  static const _logPrefix = '[MemoRecorder]';
  static const _pollInterval = Duration(milliseconds: 60);

  AudioRecorder? _recorder;
  MemoSettings _settings = const MemoSettings();
  bool _loaded = false;
  List<InputDevice> _devices = const [];
  Set<MemoFormat> _supported = {MemoFormat.wav};
  MemoStatus _status = MemoStatus.idle;
  String? _path;
  String? _lastSavedPath;
  bool _permissionDenied = false;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _poll;
  StreamSubscription<RecordState>? _stateSub;
  BackgroundWorkLease? _work;
  bool _disposed = false;

  String _notificationTitle = 'Voice memo';
  String _notificationRecording = 'Recording…';
  String _notificationPaused = 'Paused';

  final MemoLevels levels = MemoLevels();

  /// Fired after a memo is written, with the saved path.
  void Function(String path)? onSaved;

  MemoSettings get settings => _settings;
  bool get loaded => _loaded;
  List<InputDevice> get devices => _devices;
  Set<MemoFormat> get supportedFormats => _supported;
  MemoStatus get status => _status;
  bool get isActive => _status != MemoStatus.idle;
  bool get isRecording => _status == MemoStatus.recording;
  bool get isPaused => _status == MemoStatus.paused;
  bool get permissionDenied => _permissionDenied;
  String? get lastSavedPath => _lastSavedPath;

  InputDevice? get selectedDevice {
    final id = _settings.deviceId;
    if (id == null) return null;
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  Future<void> init() async {
    if (!_loaded) {
      _settings = await MemoSettings.load();
      _loaded = true;
    }
    final supported = <MemoFormat>{};
    for (final f in MemoFormat.values) {
      try {
        if (await _rec.isEncoderSupported(f.encoder)) supported.add(f);
      } catch (_) {}
    }
    _supported = supported.isEmpty ? {MemoFormat.wav} : supported;
    if (!_supported.contains(_settings.format)) {
      _settings = _settings.copyWith(format: MemoFormat.wav);
    }
    await refreshDevices();
  }

  Future<void> refreshDevices() async {
    try {
      _devices = await _rec.listInputDevices();
    } catch (e) {
      errorLog('$_logPrefix listInputDevices failed: $e');
      _devices = const [];
    }
    _notify();
  }

  void updateSettings(MemoSettings next) {
    _settings = next;
    unawaited(next.save());
    _notify();
  }

  void setNotificationText({
    required String title,
    required String recording,
    required String paused,
  }) {
    _notificationTitle = title;
    _notificationRecording = recording;
    _notificationPaused = paused;
  }

  Future<MemoStartResult> start() async {
    if (_status != MemoStatus.idle) return MemoStartResult.busy;
    _status = MemoStatus.starting;
    _notify();
    if (!_loaded) await init();

    try {
      if (!await _rec.hasPermission()) {
        _permissionDenied = true;
        _status = MemoStatus.idle;
        _notify();
        return MemoStartResult.denied;
      }
    } catch (e) {
      errorLog('$_logPrefix permission check failed: $e');
      _status = MemoStatus.idle;
      _notify();
      return MemoStartResult.failed;
    }
    _permissionDenied = false;

    final s = _settings;
    final device = selectedDevice;
    final path = await MemoStore.newRecordingPath(s.format);
    final config = RecordConfig(
      encoder: s.format.encoder,
      sampleRate: s.sampleRate,
      numChannels: s.channels,
      device: device,
      autoGain: s.autoGain,
      echoCancel: s.echoCancel,
      noiseSuppress: s.noiseSuppress,
      androidConfig: AndroidRecordConfig(
        audioSource: s.source.androidSource,
        // SCO drops capture to narrowband telephone quality; only use it
        // when the user picked the headset on purpose.
        manageBluetooth: device?.type == InputDeviceType.bluetoothSco,
      ),
    );

    try {
      await _rec.start(config, path: path);
    } catch (e) {
      errorLog('$_logPrefix start failed: $e');
      _status = MemoStatus.idle;
      _notify();
      return MemoStartResult.failed;
    }

    _path = path;
    levels._reset();
    _stopwatch
      ..reset()
      ..start();
    _status = MemoStatus.recording;
    _stateSub = _rec.onStateChanged().listen(_onPlatformState);
    _poll = Timer.periodic(_pollInterval, (_) => _onPoll());
    unawaited(_acquireWork());
    _notify();
    return MemoStartResult.ok;
  }

  Future<void> _acquireWork() async {
    final work = await BackgroundWorkLease.acquire(
      title: _notificationTitle,
      text: _notificationRecording,
      logPrefix: 'MemoRecorder',
      actions: const ['stop'],
      chronometerSinceMs: DateTime.now().millisecondsSinceEpoch,
      types: const {ForegroundServiceType.microphone},
    );
    if (!isActive) {
      await work.release();
      return;
    }
    _work = work;
    work.addActionListener((action) {
      if (action == 'stop') unawaited(stop());
    });
  }

  /// The platform pauses on its own when a call or another app takes the mic.
  void _onPlatformState(RecordState state) {
    if (state == RecordState.pause && _status == MemoStatus.recording) {
      _markPaused();
    } else if (state == RecordState.record && _status == MemoStatus.paused) {
      _markResumed();
    }
  }

  Future<void> _onPoll() async {
    if (_status != MemoStatus.recording) return;
    final max = _settings.maxSeconds;
    if (max > 0 && _stopwatch.elapsed.inSeconds >= max) {
      await stop();
      return;
    }
    try {
      final amp = await _rec.getAmplitude();
      if (_status != MemoStatus.recording) return;
      final db = amp.current.isFinite ? amp.current : MemoLevels.floorDb;
      levels._push(db, _stopwatch.elapsed);
    } catch (_) {
      levels._tick(_stopwatch.elapsed);
    }
  }

  Future<void> pause() async {
    if (_status != MemoStatus.recording) return;
    try {
      await _rec.pause();
    } catch (e) {
      errorLog('$_logPrefix pause failed: $e');
      return;
    }
    _markPaused();
  }

  Future<void> resume() async {
    if (_status != MemoStatus.paused) return;
    try {
      await _rec.resume();
    } catch (e) {
      errorLog('$_logPrefix resume failed: $e');
      return;
    }
    _markResumed();
  }

  void _markPaused() {
    _status = MemoStatus.paused;
    _stopwatch.stop();
    levels._tick(_stopwatch.elapsed);
    unawaited(_work?.update(_notificationPaused, minIntervalMs: 0));
    _notify();
  }

  void _markResumed() {
    _status = MemoStatus.recording;
    _stopwatch.start();
    unawaited(_work?.update(_notificationRecording, minIntervalMs: 0));
    _notify();
  }

  /// Finalizes the file and returns its path, or null when nothing was kept.
  Future<String?> stop() async {
    if (_status != MemoStatus.recording && _status != MemoStatus.paused) {
      return null;
    }
    _status = MemoStatus.stopping;
    _notify();
    String? saved;
    try {
      saved = await _rec.stop();
    } catch (e) {
      errorLog('$_logPrefix stop failed: $e');
    }
    saved ??= _path;
    await _finish();
    if (saved != null && await _isEmpty(saved)) {
      await _deleteQuietly(saved);
      saved = null;
    }
    if (saved != null) {
      _lastSavedPath = saved;
      if (kDebugMode) debugLog('$_logPrefix saved $saved');
      MemoStore.notifyChanged();
      onSaved?.call(saved);
    }
    _notify();
    return saved;
  }

  /// Stops and deletes the in-progress file.
  Future<void> discard() async {
    if (_status != MemoStatus.recording && _status != MemoStatus.paused) {
      return;
    }
    _status = MemoStatus.stopping;
    _notify();
    final path = _path;
    try {
      await _rec.cancel();
    } catch (e) {
      errorLog('$_logPrefix cancel failed: $e');
    }
    await _finish();
    if (path != null) await _deleteQuietly(path);
    _notify();
  }

  Future<void> _finish() async {
    _poll?.cancel();
    _poll = null;
    await _stateSub?.cancel();
    _stateSub = null;
    _stopwatch.stop();
    _path = null;
    _status = MemoStatus.idle;
    final work = _work;
    _work = null;
    await work?.release();
  }

  Future<bool> _isEmpty(String path) async {
    try {
      return await File(path).length() <= 64;
    } catch (_) {
      return true;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _stateSub?.cancel();
    unawaited(_work?.release());
    final rec = _recorder;
    if (rec != null) unawaited(rec.dispose());
    levels.dispose();
    super.dispose();
  }
}

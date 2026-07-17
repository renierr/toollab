import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../helpers/wav_pcm16_encoder.dart';
import '../../services/database_service.dart';
import 'audio/doppler_analyzer.dart';
import 'audio/mic_analyzer.dart';
import 'audio/tone_generator.dart';
import 'config.dart';

enum SfMode { tracker, counter, generator, doppler }

enum MicStatus { idle, running, denied, unavailable }

enum TrackerTrend { hotter, colder, steady, silent }

/// Coordinates microphone analysis and tone synthesis for the three tool modes:
/// locating an unwanted sound, generating a counter/masking tone, and a plain
/// frequency generator.
class SoundFinderState extends ChangeNotifier {
  static String get _toolId => SoundFinderTool.config.id;

  static const String _kGenFreq = 'gen_freq';
  static const String _kGenWave = 'gen_wave';
  static const String _kGenVol = 'gen_vol';
  static const String _kCtrWave = 'ctr_wave';
  static const String _kCtrVol = 'ctr_vol';
  static const String _kCtrPhase = 'ctr_phase';
  static const String _kCtrNoise = 'ctr_noise';
  static const String _kMicDevice = 'mic_device';
  static const String _kMicGain = 'mic_gain';
  static const String _kSpectrumRes = 'spectrum_res';

  static const double maxMicGain = 20;

  final MicAnalyzer _mic = MicAnalyzer();
  final ToneGenerator _tone = ToneGenerator();
  StreamSubscription<MicAnalysis>? _micSub;

  SfMode _mode = SfMode.tracker;
  MicStatus _micStatus = MicStatus.idle;

  // Input device selection.
  List<InputDevice> _inputDevices = const [];
  InputDevice? _selectedDevice;
  String? _pendingDeviceId; // restored id, matched once devices are listed
  double _micGain = 1.0;

  // Smoothed live analysis.
  MicAnalysis _analysis = MicAnalysis.zero();
  double _smoothDb = -90;
  double _smoothPeakHz = 0;
  final List<double> _dbHistory = [];
  static const int _historyLen = 16;

  // Tracker reference marker.
  double? _referenceDb;
  double _peakHoldDb = -90;

  // Generator config.
  double _genFreq = 440;
  ToneWaveform _genWave = ToneWaveform.sine;
  double _genVol = 0.4;

  // Counter config.
  double _counterFreq = 100;
  ToneWaveform _counterWave = ToneWaveform.sine;
  double _counterVol = 0.4;
  double _counterPhaseDeg = 180;
  double _counterNoise = 0;

  // Doppler analysis data.
  Float32List? _dopplerSamples;
  DopplerResult? _dopplerResult;

  bool _tonePlaying = false;
  SfMode? _toneOwner;

  SoundFinderState() {
    _micSub = _mic.stream.listen(_onAnalysis);
    _tone.onExternalStop = _onToneExternalStop;
    _mic.onRecordLimitReached = notifyListeners;
    _restore();
  }

  void _onToneExternalStop() {
    _tonePlaying = false;
    _toneOwner = null;
    notifyListeners();
  }

  // Getters.
  SfMode get mode => _mode;
  MicStatus get micStatus => _micStatus;
  List<InputDevice> get inputDevices => _inputDevices;
  InputDevice? get selectedDevice => _selectedDevice;
  double get micGain => _micGain;
  SpectrumResolution get spectrumResolution => _mic.resolution;
  bool get isRecording => _mic.isRecording;
  double get recordedSeconds => _mic.recordedSeconds;
  static int get maxRecordSeconds => MicAnalyzer.maxRecordSeconds;
  MicAnalysis get analysis => _analysis;
  double get smoothDb => _smoothDb;
  double get smoothPeakHz => _smoothPeakHz;
  double get peakHoldDb => _peakHoldDb;
  double? get referenceDb => _referenceDb;

  double get genFreq => _genFreq;
  ToneWaveform get genWave => _genWave;
  double get genVol => _genVol;

  double get counterFreq => _counterFreq;
  ToneWaveform get counterWave => _counterWave;
  double get counterVol => _counterVol;
  double get counterPhaseDeg => _counterPhaseDeg;
  double get counterNoise => _counterNoise;

  Float32List? get dopplerSamples => _dopplerSamples;
  DopplerResult? get dopplerResult => _dopplerResult;

  bool get tonePlaying => _tonePlaying;
  SfMode? get toneOwner => _toneOwner;

  bool get generatorPlaying => _tonePlaying && _toneOwner == SfMode.generator;
  bool get counterPlaying => _tonePlaying && _toneOwner == SfMode.counter;

  /// Loudness normalized to 0..1 over a -70..0 dBFS range for the meter.
  double get levelNorm => ((_smoothDb + 70) / 70).clamp(0.0, 1.0);

  double? get referenceDelta =>
      _referenceDb == null ? null : _smoothDb - _referenceDb!;

  TrackerTrend get trend {
    if (_smoothDb < -65) return TrackerTrend.silent;
    if (_dbHistory.length < 6) return TrackerTrend.steady;
    final int half = _dbHistory.length ~/ 2;
    double older = 0;
    for (int i = 0; i < half; i++) {
      older += _dbHistory[i];
    }
    older /= half;
    final double delta = _smoothDb - older;
    if (delta > 1.5) return TrackerTrend.hotter;
    if (delta < -1.5) return TrackerTrend.colder;
    return TrackerTrend.steady;
  }

  Future<void> setMode(SfMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    // Stop any tone when switching context to avoid surprise playback.
    if (_tonePlaying) await _stopTone();
    notifyListeners();

    if (mode == SfMode.generator) {
      await _stopMic();
    } else {
      await ensureMic();
    }
  }

  Future<void> ensureMic() async {
    if (_micStatus == MicStatus.running) return;
    final MicStartResult result = await _mic.start();
    _micStatus = switch (result) {
      MicStartResult.ok => MicStatus.running,
      MicStartResult.denied => MicStatus.denied,
      MicStartResult.unavailable => MicStatus.unavailable,
    };
    notifyListeners();
    if (_micStatus == MicStatus.running) await refreshInputDevices();
  }

  /// Re-enumerates capture devices and reconciles the current selection: a
  /// vanished device falls back to the default, and a pending restored id is
  /// resolved once it appears.
  Future<void> refreshInputDevices() async {
    _inputDevices = await _mic.listInputDevices();
    if (_selectedDevice != null && _findDevice(_selectedDevice!.id) == null) {
      _selectedDevice = null;
      _mic.device = null;
    } else if (_selectedDevice == null && _pendingDeviceId != null) {
      final InputDevice? match = _findDevice(_pendingDeviceId!);
      if (match != null) {
        _selectedDevice = match;
        _mic.device = match;
        if (_micStatus == MicStatus.running) await _restartMic();
      }
    }
    notifyListeners();
  }

  void setSpectrumResolution(SpectrumResolution r) {
    if (r == _mic.resolution) return;
    _mic.setResolution(r);
    _save(_kSpectrumRes, r.name);
    notifyListeners();
  }

  void setMicGain(double gain) {
    final double clamped = gain.clamp(1.0, maxMicGain);
    if (clamped == _micGain) return;
    _micGain = clamped;
    _mic.gain = clamped;
    _save(_kMicGain, clamped.toStringAsFixed(2));
    notifyListeners();
  }

  void startRecording() {
    if (_micStatus != MicStatus.running || _mic.isRecording) return;
    _mic.startRecording();
    notifyListeners();
  }

  /// Stops the active recording and returns it as a 16-bit PCM WAV, or `null`
  /// if nothing was captured.
  Uint8List? stopRecordingToWav() {
    final Float32List samples = _mic.stopRecording();
    notifyListeners();
    if (samples.isEmpty) {
      _dopplerSamples = null;
      _dopplerResult = null;
      return null;
    }
    _dopplerSamples = samples;
    _dopplerResult = DopplerAnalyzer.analyze(samples, MicAnalyzer.sampleRate);
    return WavPcm16Encoder.encode(
      samples,
      frames: samples.length,
      sampleRate: MicAnalyzer.sampleRate,
      channels: 1,
    );
  }

  /// Generates a synthetic Doppler shift audio clip for testing and demonstration.
  void loadDemoClip() {
    final int sampleRate = MicAnalyzer.sampleRate;
    final int length = sampleRate * 5; // 5 seconds
    final Float32List samples = Float32List(length);

    // Physical parameters for demo:
    // f0 = 450 Hz
    // v = 25 m/s (~90 km/h)
    // c = 343.4 m/s
    // d = 4.0 meters
    // t0 = 2.5 seconds
    const double f0 = 450.0;
    const double v = 25.0;
    const double c = 343.4;
    const double d = 4.0;
    const double t0 = 2.5;

    double phase = 0.0;
    for (int i = 0; i < length; i++) {
      final double t = i / sampleRate;
      final double distOffset = v * (t - t0);
      final double cosTheta =
          distOffset / math.sqrt(d * d + distOffset * distOffset);
      final double freq = f0 / (1.0 - (v / c) * cosTheta);

      phase += 2.0 * math.pi * freq / sampleRate;
      final double distance = math.sqrt(d * d + distOffset * distOffset);
      final double amp = 1.0 / (1.0 + 0.1 * distance * distance);
      // Generate tone with a tiny bit of random noise for realism
      final double noise = (math.Random().nextDouble() - 0.5) * 0.02;
      samples[i] = (math.sin(phase) * amp * 0.5 + noise).clamp(-1.0, 1.0);
    }

    _dopplerSamples = samples;
    _dopplerResult = DopplerAnalyzer.analyze(samples, sampleRate);
    notifyListeners();
  }

  /// Clears current Doppler recording/data.
  void clearDopplerData() {
    _dopplerSamples = null;
    _dopplerResult = null;
    notifyListeners();
  }

  Future<void> selectInputDevice(InputDevice? device) async {
    if (device?.id == _selectedDevice?.id) return;
    _selectedDevice = device;
    _pendingDeviceId = device?.id;
    _mic.device = device;
    _save(_kMicDevice, device?.id ?? '');
    if (_micStatus == MicStatus.running) await _restartMic();
    notifyListeners();
  }

  InputDevice? _findDevice(String id) {
    for (final InputDevice d in _inputDevices) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> _restartMic() async {
    await _mic.stop();
    _micStatus = MicStatus.idle;
    final MicStartResult result = await _mic.start();
    _micStatus = switch (result) {
      MicStartResult.ok => MicStatus.running,
      MicStartResult.denied => MicStatus.denied,
      MicStartResult.unavailable => MicStatus.unavailable,
    };
  }

  void _onAnalysis(MicAnalysis a) {
    _analysis = a;
    const double k = 0.3;
    _smoothDb = _smoothDb + k * (a.db - _smoothDb);
    if (a.peakLevel > 1e-6) {
      _smoothPeakHz = _smoothPeakHz + k * (a.peakFreqHz - _smoothPeakHz);
    }
    if (_smoothDb > _peakHoldDb) _peakHoldDb = _smoothDb;

    _dbHistory.add(_smoothDb);
    if (_dbHistory.length > _historyLen) _dbHistory.removeAt(0);

    notifyListeners();
  }

  // --- Tracker actions ---

  void markReference() {
    _referenceDb = _smoothDb;
    notifyListeners();
  }

  void clearReference() {
    _referenceDb = null;
    notifyListeners();
  }

  void resetPeakHold() {
    _peakHoldDb = _smoothDb;
    notifyListeners();
  }

  // --- Generator actions ---

  void setGenFreq(double hz) {
    _genFreq = hz.clamp(20, 20000);
    if (generatorPlaying) _tone.setFrequency(_genFreq);
    _save(_kGenFreq, _genFreq.toStringAsFixed(2));
    notifyListeners();
  }

  void setGenWave(ToneWaveform w) {
    _genWave = w;
    if (generatorPlaying) _tone.setWaveform(w);
    _save(_kGenWave, w.name);
    notifyListeners();
  }

  void setGenVol(double v) {
    _genVol = v.clamp(0.0, 1.0);
    if (generatorPlaying) _tone.setVolume(_genVol);
    _save(_kGenVol, _genVol.toStringAsFixed(3));
    notifyListeners();
  }

  Future<void> toggleGenerator() async {
    if (generatorPlaying) {
      await _stopTone();
      return;
    }
    if (_tonePlaying) await _stopTone();
    _tone.setFrequency(_genFreq);
    _tone.setWaveform(_genWave);
    _tone.setPhaseOffset(0);
    _tone.setNoiseMix(0);
    _tone.setVolume(_genVol);
    await _tone.start();
    _tonePlaying = true;
    _toneOwner = SfMode.generator;
    notifyListeners();
  }

  // --- Counter actions ---

  void useDetectedFrequency() {
    if (_smoothPeakHz > 0) {
      _counterFreq = _smoothPeakHz.clamp(20, 20000);
      if (counterPlaying) _tone.setFrequency(_counterFreq);
      notifyListeners();
    }
  }

  void setCounterFreq(double hz) {
    _counterFreq = hz.clamp(20, 20000);
    if (counterPlaying) _tone.setFrequency(_counterFreq);
    notifyListeners();
  }

  void setCounterWave(ToneWaveform w) {
    _counterWave = w;
    if (counterPlaying) _tone.setWaveform(w);
    _save(_kCtrWave, w.name);
    notifyListeners();
  }

  void setCounterVol(double v) {
    _counterVol = v.clamp(0.0, 1.0);
    if (counterPlaying) _tone.setVolume(_counterVol);
    _save(_kCtrVol, _counterVol.toStringAsFixed(3));
    notifyListeners();
  }

  void setCounterPhaseDeg(double deg) {
    _counterPhaseDeg = deg.clamp(0.0, 360.0);
    if (counterPlaying) _tone.setPhaseOffset(_phaseRadians);
    _save(_kCtrPhase, _counterPhaseDeg.toStringAsFixed(1));
    notifyListeners();
  }

  void setCounterNoise(double v) {
    _counterNoise = v.clamp(0.0, 1.0);
    if (counterPlaying) _tone.setNoiseMix(_counterNoise);
    _save(_kCtrNoise, _counterNoise.toStringAsFixed(3));
    notifyListeners();
  }

  double get _phaseRadians => _counterPhaseDeg * math.pi / 180.0;

  Future<void> toggleCounter() async {
    if (counterPlaying) {
      await _stopTone();
      return;
    }
    if (_tonePlaying) await _stopTone();
    _tone.setFrequency(_counterFreq);
    _tone.setWaveform(_counterWave);
    _tone.setPhaseOffset(_phaseRadians);
    _tone.setNoiseMix(_counterNoise);
    _tone.setVolume(_counterVol);
    await _tone.start();
    _tonePlaying = true;
    _toneOwner = SfMode.counter;
    notifyListeners();
  }

  Future<void> _stopTone() async {
    await _tone.stop();
    _tonePlaying = false;
    _toneOwner = null;
    notifyListeners();
  }

  Future<void> _stopMic() async {
    if (_micStatus != MicStatus.running) return;
    await _mic.stop();
    _micStatus = MicStatus.idle;
    _dbHistory.clear();
    notifyListeners();
  }

  /// Called when the tool page becomes active. Starts the mic for the modes
  /// that need it.
  Future<void> onPageEnter() async {
    if (_mode != SfMode.generator) await ensureMic();
  }

  /// Called when the tool page is disposed. Releases the mic, but keeps any
  /// playing tone alive in the background via the foreground service — it is
  /// stopped from the notification's stop action or when playback is toggled
  /// off again in the tool.
  Future<void> onPageLeave() async {
    await _stopMic();
    _peakHoldDb = -90;
    _referenceDb = null;
    _suspended = false;
  }

  bool _suspended = false;

  /// App went to background — suspend the mic and all graph visualizations to
  /// reduce CPU. Will resume on foreground.
  Future<void> onAppBackgrounded() async {
    if (_micStatus != MicStatus.running) return;
    await _mic.stop();
    _suspended = true;
  }

  /// App returned to foreground — resume the mic if it was suspended.
  Future<void> onAppForegrounded() async {
    if (!_suspended) return;
    _suspended = false;
    if (_mode != SfMode.generator) {
      final MicStartResult result = await _mic.start();
      if (result != MicStartResult.ok) {
        _micStatus = switch (result) {
          MicStartResult.denied => MicStatus.denied,
          MicStartResult.unavailable => MicStatus.unavailable,
          _ => MicStatus.idle,
        };
      }
    }
    notifyListeners();
  }

  void setNotificationText({required String title, required String text}) {
    _tone.notificationTitle = title;
    _tone.notificationText = text;
  }

  Future<void> _restore() async {
    final db = DatabaseService.instance;
    final genFreq = await db.getSetting(_toolId, _kGenFreq);
    final genWave = await db.getSetting(_toolId, _kGenWave);
    final genVol = await db.getSetting(_toolId, _kGenVol);
    final ctrWave = await db.getSetting(_toolId, _kCtrWave);
    final ctrVol = await db.getSetting(_toolId, _kCtrVol);
    final ctrPhase = await db.getSetting(_toolId, _kCtrPhase);
    final ctrNoise = await db.getSetting(_toolId, _kCtrNoise);
    final micDevice = await db.getSetting(_toolId, _kMicDevice);
    final micGain = await db.getSetting(_toolId, _kMicGain);
    final spectrumRes = await db.getSetting(_toolId, _kSpectrumRes);
    final SpectrumResolution? res = _resolutionFromName(spectrumRes);
    if (res != null) _mic.setResolution(res);
    _pendingDeviceId = (micDevice != null && micDevice.isNotEmpty)
        ? micDevice
        : null;
    _micGain = double.tryParse(micGain ?? '')?.clamp(1.0, maxMicGain) ?? 1.0;
    _mic.gain = _micGain;

    _genFreq = double.tryParse(genFreq ?? '')?.clamp(20, 20000) ?? 440;
    _genWave = _waveFromName(genWave) ?? ToneWaveform.sine;
    _genVol = double.tryParse(genVol ?? '')?.clamp(0.0, 1.0) ?? 0.4;
    _counterWave = _waveFromName(ctrWave) ?? ToneWaveform.sine;
    _counterVol = double.tryParse(ctrVol ?? '')?.clamp(0.0, 1.0) ?? 0.4;
    _counterPhaseDeg =
        double.tryParse(ctrPhase ?? '')?.clamp(0.0, 360.0) ?? 180;
    _counterNoise = double.tryParse(ctrNoise ?? '')?.clamp(0.0, 1.0) ?? 0;
    notifyListeners();
  }

  SpectrumResolution? _resolutionFromName(String? name) {
    if (name == null) return null;
    for (final r in SpectrumResolution.values) {
      if (r.name == name) return r;
    }
    return null;
  }

  ToneWaveform? _waveFromName(String? name) {
    if (name == null) return null;
    for (final w in ToneWaveform.values) {
      if (w.name == name) return w;
    }
    return null;
  }

  void _save(String key, String value) {
    DatabaseService.instance.setSetting(_toolId, key, value);
  }

  @override
  void dispose() {
    _micSub?.cancel();
    _mic.dispose();
    _tone.dispose();
    super.dispose();
  }
}

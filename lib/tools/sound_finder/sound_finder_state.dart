import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import '../../helpers/temp_file_manager.dart';
import '../../helpers/wav_decoder.dart';
import '../../helpers/wav_pcm16_encoder.dart';
import '../../services/database_service.dart';
import 'audio/doppler_analyzer.dart';
import 'audio/mic_analyzer.dart';
import 'audio/tone_generator.dart';
import 'config.dart';
import 'morse/morse_audio_renderer.dart';
import 'morse/morse_converter.dart';
import 'morse/morse_decoder.dart';

enum SfMode { tracker, counter, generator, doppler, morse }

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
  String? _tempWavPath;

  bool _tonePlaying = false;
  SfMode? _toneOwner;

  // Morse fields.
  double _morseWpm = 20;
  double _morseFreq = 600;
  double _morseVolume = 0.5;
  String _morsePlayMode = 'both'; // 'both', 'sound', 'flash'
  String _morseInputText = 'HELLO WORLD';
  String _morseDecodedText = '';
  bool _morsePlaying = false;
  int _morsePlayingTokenIndex = -1;
  bool _morseFlashActive = false;
  int _morsePlaybackSessionId = 0;
  SoundHandle? _morseHandle;
  AudioSource? _morseSource;

  // Live listening / decoding.
  bool _morseListening = false;
  StreamSubscription<Float32List>? _morsePcmSub;
  final List<Float32List> _morseChunks = [];
  Timer? _morseDecodeTimer;
  bool _morseIsDecodingLive = false;

  // Morse settings keys
  static const String _kMorseWpm = 'morse_wpm';
  static const String _kMorseFreq = 'morse_freq';
  static const String _kMorsePlayMode = 'morse_play_mode';
  static const String _kMorseVolume = 'morse_volume';

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
  String? get tempWavPath => _tempWavPath;

  bool get tonePlaying => _tonePlaying;
  SfMode? get toneOwner => _toneOwner;

  bool get generatorPlaying => _tonePlaying && _toneOwner == SfMode.generator;
  bool get counterPlaying => _tonePlaying && _toneOwner == SfMode.counter;

  double get morseWpm => _morseWpm;
  double get morseFreq => _morseFreq;
  double get morseVolume => _morseVolume;
  String get morsePlayMode => _morsePlayMode;
  String get morseInputText => _morseInputText;
  String get morseDecodedText => _morseDecodedText;
  bool get morsePlaying => _morsePlaying;
  int get morsePlayingTokenIndex => _morsePlayingTokenIndex;
  bool get morseFlashActive => _morseFlashActive;
  bool get morseListening => _morseListening;
  bool get morseIsDecodingLive => _morseIsDecodingLive;

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
    if (_morsePlaying) await stopMorsePlayback();
    if (_morseListening) await stopMorseListening();
    notifyListeners();

    if (mode == SfMode.generator || mode == SfMode.morse) {
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

  /// Stops the active recording, runs analysis, and saves to a temp WAV file.
  Future<void> stopRecordingAndSaveTemp() async {
    final Float32List samples = _mic.stopRecording();
    if (samples.isEmpty) {
      _dopplerSamples = null;
      _dopplerResult = null;
      _tempWavPath = null;
      notifyListeners();
      return;
    }
    _dopplerSamples = samples;
    _dopplerResult = DopplerAnalyzer.analyze(samples, MicAnalyzer.sampleRate);
    final wavBytes = WavPcm16Encoder.encode(
      samples,
      frames: samples.length,
      sampleRate: MicAnalyzer.sampleRate,
      channels: 1,
    );
    if (wavBytes.isNotEmpty) {
      _tempWavPath = await TempFileManager.createFile(
        'interim_sound_clip.wav',
        bytes: wavBytes,
      );
    } else {
      _tempWavPath = null;
    }
    notifyListeners();
  }

  /// Loads a recorded/saved WAV file, decodes it, and sets it for Doppler analysis.
  void loadWavClip(Uint8List wavBytes) {
    final decoded = WavDecoder.decode(wavBytes);
    if (decoded == null) {
      _dopplerSamples = null;
      _dopplerResult = null;
      _tempWavPath = null;
      notifyListeners();
      return;
    }

    _dopplerSamples = decoded.samples;
    _dopplerResult = DopplerAnalyzer.analyze(
      decoded.samples,
      decoded.sampleRate,
    );

    // Save to temp folder so it can be re-saved/exported
    TempFileManager.createFile('interim_sound_clip.wav', bytes: wavBytes)
        .then((path) {
          _tempWavPath = path;
          notifyListeners();
        })
        .catchError((_) {
          _tempWavPath = null;
          notifyListeners();
        });
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
    await stopMorsePlayback();
    await stopMorseListening();
    _peakHoldDb = -90;
    _referenceDb = null;
    _suspended = false;
    if (_tempWavPath != null) {
      try {
        await TempFileManager.deleteFile('interim_sound_clip.wav');
      } catch (_) {}
      _tempWavPath = null;
    }
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

  // --- Morse Actions ---

  void setMorseWpm(double val) {
    _morseWpm = val.clamp(10, 45);
    _save(_kMorseWpm, _morseWpm.toStringAsFixed(0));
    notifyListeners();
  }

  void setMorseFreq(double val) {
    _morseFreq = val.clamp(400, 1000);
    _save(_kMorseFreq, _morseFreq.toStringAsFixed(0));
    notifyListeners();
  }

  void setMorseVolume(double val) {
    _morseVolume = val.clamp(0.0, 1.0);
    _save(_kMorseVolume, _morseVolume.toStringAsFixed(2));
    if (_morsePlaying && _morseHandle != null) {
      SoLoud.instance.setVolume(_morseHandle!, _morseVolume);
    }
    notifyListeners();
  }

  void setMorsePlayMode(String val) {
    _morsePlayMode = val;
    _save(_kMorsePlayMode, val);
    notifyListeners();
  }

  void setMorseInputText(String val) {
    _morseInputText = val;
    notifyListeners();
  }

  Future<void> startMorsePlayback() async {
    if (_morsePlaying) return;
    _morsePlaying = true;
    _morsePlayingTokenIndex = -1;
    _morseFlashActive = false;
    notifyListeners();

    final int sessionId = ++_morsePlaybackSessionId;
    final tokens = MorseConverter.tokenize(_morseInputText);
    if (tokens.isEmpty) {
      _morsePlaying = false;
      notifyListeners();
      return;
    }

    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }

      final bool playSound =
          _morsePlayMode == 'both' || _morsePlayMode == 'sound';
      final bool playFlash =
          _morsePlayMode == 'both' || _morsePlayMode == 'flash';

      if (playSound) {
        final wavBytes = await MorseAudioRenderer.render(
          tokens: tokens,
          wpm: _morseWpm,
          frequency: _morseFreq,
        );

        if (sessionId != _morsePlaybackSessionId) return;

        final AudioSource source = await SoLoud.instance.loadMem(
          'sf_morse_$sessionId.wav',
          wavBytes,
        );
        _morseSource = source;

        final SoundHandle handle = SoLoud.instance.play(
          source,
          volume: _morseVolume,
        );
        _morseHandle = handle;
      }

      final double unitSec = 1.2 / _morseWpm;
      final int unitMs = (unitSec * 1000).round();

      for (int i = 0; i < tokens.length; i++) {
        if (sessionId != _morsePlaybackSessionId) return;

        _morsePlayingTokenIndex = i;
        notifyListeners();

        final token = tokens[i];
        if (token.isWordGap) {
          await Future.delayed(Duration(milliseconds: 7 * unitMs));
        } else if (token.isCharGap) {
          await Future.delayed(Duration(milliseconds: 3 * unitMs));
        } else {
          final code = token.morse;
          for (int j = 0; j < code.length; j++) {
            if (sessionId != _morsePlaybackSessionId) return;

            final sym = code[j];
            final int durUnits = sym == '-' ? 3 : 1;

            if (playFlash) {
              _morseFlashActive = true;
              notifyListeners();
            }

            await Future.delayed(Duration(milliseconds: durUnits * unitMs));

            if (playFlash) {
              _morseFlashActive = false;
              notifyListeners();
            }

            if (j < code.length - 1) {
              await Future.delayed(Duration(milliseconds: 1 * unitMs));
            }
          }
        }
      }
    } catch (e) {
      errorLog('[SoundFinderState] Morse playback failed: $e');
    } finally {
      if (sessionId == _morsePlaybackSessionId) {
        await stopMorsePlayback();
      }
    }
  }

  Future<void> stopMorsePlayback() async {
    _morsePlaybackSessionId++;
    _morsePlaying = false;
    _morsePlayingTokenIndex = -1;
    _morseFlashActive = false;

    final handle = _morseHandle;
    final source = _morseSource;
    _morseHandle = null;
    _morseSource = null;

    if (handle != null) {
      await SoLoud.instance.stop(handle);
    }
    if (source != null) {
      SoLoud.instance.disposeSource(source);
    }

    notifyListeners();
  }

  Future<void> startMorseListening() async {
    if (_morseListening) return;

    final hasPerm = await _mic.hasPermission();
    if (!hasPerm) {
      _micStatus = MicStatus.denied;
      notifyListeners();
      return;
    }

    final startRes = await _mic.start();
    if (startRes != MicStartResult.ok) {
      _micStatus = startRes == MicStartResult.denied
          ? MicStatus.denied
          : MicStatus.unavailable;
      notifyListeners();
      return;
    }

    _micStatus = MicStatus.running;
    _morseListening = true;
    _morseDecodedText = '';
    _morseChunks.clear();
    _morseFlashActive = false;
    notifyListeners();

    _morsePcmSub = _mic.pcmStream.listen((chunk) {
      double sumSq = 0;
      for (int i = 0; i < chunk.length; i++) {
        sumSq += chunk[i] * chunk[i];
      }
      final double rms = math.sqrt(sumSq / chunk.length);

      final bool active = rms > 0.008;
      if (active != _morseFlashActive) {
        _morseFlashActive = active;
        notifyListeners();
      }

      const int maxSamples = MicAnalyzer.sampleRate * 60;
      int currentSamples = _morseChunks.fold(
        0,
        (sum, element) => sum + element.length,
      );
      if (currentSamples + chunk.length <= maxSamples) {
        _morseChunks.add(chunk);
      } else {
        if (_morseChunks.isNotEmpty) {
          _morseChunks.removeAt(0);
        }
        _morseChunks.add(chunk);
      }
    });

    _morseDecodeTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      if (_morseChunks.isEmpty || _morseIsDecodingLive) return;

      _morseIsDecodingLive = true;
      notifyListeners();

      try {
        int totalLength = _morseChunks.fold(
          0,
          (sum, element) => sum + element.length,
        );
        final Float32List combined = Float32List(totalLength);
        int offset = 0;
        for (final chunk in _morseChunks) {
          combined.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        final decoded = await MorseDecoder.decode(
          samples: combined,
          sampleRate: MicAnalyzer.sampleRate,
        );

        if (_morseListening) {
          _morseDecodedText = decoded;
        }
      } catch (e) {
        errorLog('[SoundFinderState] Live decode error: $e');
      } finally {
        _morseIsDecodingLive = false;
        notifyListeners();
      }
    });
  }

  Future<void> stopMorseListening() async {
    if (!_morseListening) return;
    _morseListening = false;
    _morseFlashActive = false;
    _morseIsDecodingLive = false;

    await _morsePcmSub?.cancel();
    _morsePcmSub = null;

    _morseDecodeTimer?.cancel();
    _morseDecodeTimer = null;

    _morseChunks.clear();

    await _stopMic();
    notifyListeners();
  }

  void clearMorseDecodedText() {
    _morseDecodedText = '';
    _morseChunks.clear();
    notifyListeners();
  }

  Future<void> _restore() async {
    final db = DatabaseService.instance;
    final genFreq = await db.getSetting(_toolId, _kGenFreq);
    final morseWpm = await db.getSetting(_toolId, _kMorseWpm);
    final morseFreq = await db.getSetting(_toolId, _kMorseFreq);
    final morsePlayMode = await db.getSetting(_toolId, _kMorsePlayMode);
    final morseVolume = await db.getSetting(_toolId, _kMorseVolume);

    _morseWpm = double.tryParse(morseWpm ?? '')?.clamp(10.0, 45.0) ?? 20.0;
    _morseFreq =
        double.tryParse(morseFreq ?? '')?.clamp(400.0, 1000.0) ?? 600.0;
    _morsePlayMode = morsePlayMode ?? 'both';
    _morseVolume = double.tryParse(morseVolume ?? '')?.clamp(0.0, 1.0) ?? 0.5;
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
    _morsePcmSub?.cancel();
    _morseDecodeTimer?.cancel();
    _mic.dispose();
    _tone.dispose();
    super.dispose();
  }
}

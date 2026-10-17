import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import '../../helpers/temp_file_manager.dart';
import '../voice_distorter/engine/wav_utils.dart';
import 'recording_clip.dart';
import 'sf_recording_format.dart';
import '../../helpers/wav_decoder.dart';
import '../../helpers/wav_pcm16_encoder.dart';
import '../../services/database_service.dart';
import '../../services/power_wake_lock_service.dart';
import 'audio/doppler_analyzer.dart';
import 'audio/mic_analyzer.dart';
import 'audio/tone_generator.dart';
import 'config.dart';
import 'morse/morse_audio_renderer.dart';
import 'morse/morse_converter.dart';
import 'morse/morse_decoder.dart';

enum SfMode { tracker, counter, generator, doppler, morse, recordings, sleep }

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
  static const String _kMaxRecordSeconds = 'max_record_seconds';
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
  int _maxRecordSeconds = MicAnalyzer.defaultMaxRecordSeconds;
  int _sampleRate = MicAnalyzer.sampleRate;
  bool _noiseSuppress = false;
  bool _echoCancel = false;
  bool _autoGain = false;

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

  // Disk-streamed normal recordings.
  bool _diskRecording = false;
  IOSink? _diskRecSink;
  Timer? _diskRecTimer;
  StreamSubscription<Float32List>? _diskWaveformSub;
  final List<double> _diskWaveform = List<double>.filled(2048, 0);
  int _diskWaveformPos = 0;
  DateTime? _normalRecStart;
  double _playbackSpeed = 1.0;

  // Playback of stored clips.
  String? _playingRecordingPath;
  SoundHandle? _playingHandle;
  AudioSource? _playingSource;
  StreamSubscription<StreamSoundEvent>? _playingEndSub;
  Timer? _playbackTimer;
  Duration _playbackPosition = Duration.zero;
  double _playbackVolume = 1.0;

  // Normal recordings (stored clips).
  List<RecordingClip> _recordings = const [];
  bool _recordingsExporting = false;
  String? _recordingsDirPath;

  // Sleep sound recorder.
  bool _sleepActive = false;
  int _sleepDurationMinutes = 480;
  DateTime? _sleepStart;
  int _sleepChunksKept = 0;
  String? _sleepDirPath;
  String? _sleepSessionDir;
  String? _sleepError;
  double _sleepThreshold = 0.005;
  double _sleepLiveDb = -90;
  DateTime? _sleepLastEvent;
  final List<String> _sleepSessionFiles = [];
  List<String> get sleepSessionFiles => List.unmodifiable(_sleepSessionFiles);
  String? get sleepError => _sleepError;
  double get sleepThreshold => _sleepThreshold;
  double get sleepLiveDb => _sleepLiveDb;
  DateTime? get sleepLastEvent => _sleepLastEvent;
  Timer? _sleepTimeout;
  Timer? _sleepChunkTimer;
  WakeLockLease? _sleepWakeLock;

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
    _mic.onRecordLimitReached = () {
      if (_mode == SfMode.recordings) {
        unawaited(stopRecordingAndStore());
      } else {
        notifyListeners();
      }
    };
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
  int get maxRecordSeconds => _maxRecordSeconds;
  int get sampleRate => _sampleRate;
  bool get noiseSuppress => _noiseSuppress;
  bool get echoCancel => _echoCancel;
  bool get autoGain => _autoGain;
  SpectrumResolution get spectrumResolution => _mic.resolution;
  bool get isRecording => _mic.isRecording || _diskRecording;
  bool get isPaused => _diskRecording && _mic.isPaused;
  double get recordedSeconds => _mic.recordedSeconds;
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

  List<RecordingClip> get recordings => _recordings;
  bool get recordingsExporting => _recordingsExporting;

  bool get sleepActive => _sleepActive;
  int get sleepDurationMinutes => _sleepDurationMinutes;
  DateTime? get sleepStart => _sleepStart;
  int get sleepChunksKept => _sleepChunksKept;
  Duration get sleepElapsed => _sleepStart == null
      ? Duration.zero
      : DateTime.now().difference(_sleepStart!);
  List<double> get diskWaveform => _diskWaveform;
  String? get playingRecordingPath => _playingRecordingPath;
  double get playbackSpeed => _playbackSpeed;
  Duration get playbackPosition => _playbackPosition;
  double get playbackVolume => _playbackVolume;

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
    if (_mode == SfMode.sleep && _sleepActive) {
      await stopSleep();
    }
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
    _syncMicConfig();
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

  void setMaxRecordSeconds(int seconds) {
    final int clamped = seconds < 0 ? 0 : seconds;
    if (clamped == _maxRecordSeconds) return;
    _maxRecordSeconds = clamped;
    _mic.maxRecordSeconds = clamped;
    _save(_kMaxRecordSeconds, clamped.toString());
    notifyListeners();
  }

  void setSampleRate(int rate) {
    if (rate == _sampleRate) return;
    _sampleRate = rate;
    MicAnalyzer.sampleRate = rate;
    _save('sf_sample_rate', rate.toString());
    if (_micStatus == MicStatus.running) {
      unawaited(_restartMic());
    }
    notifyListeners();
  }

  void setNoiseSuppress(bool value) {
    if (value == _noiseSuppress) return;
    _noiseSuppress = value;
    _save('sf_noise_suppress', value.toString());
    if (_micStatus == MicStatus.running) {
      unawaited(_restartMic());
    }
    notifyListeners();
  }

  void setEchoCancel(bool value) {
    if (value == _echoCancel) return;
    _echoCancel = value;
    _save('sf_echo_cancel', value.toString());
    if (_micStatus == MicStatus.running) {
      unawaited(_restartMic());
    }
    notifyListeners();
  }

  void setAutoGain(bool value) {
    if (value == _autoGain) return;
    _autoGain = value;
    _save('sf_auto_gain', value.toString());
    if (_micStatus == MicStatus.running) {
      unawaited(_restartMic());
    }
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

  /// Persistent directory holding stored mic recordings.
  Future<String> _recordingsDir() async {
    if (_recordingsDirPath != null) return _recordingsDirPath!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/audio_recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    _recordingsDirPath = dir.path;
    return dir.path;
  }

  Future<void> refreshRecordings() async {
    final dirPath = await _recordingsDir();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      _recordings = const [];
      notifyListeners();
      return;
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ext == 'wav' ||
              ext == 'm4a' ||
              ext == 'mp3' ||
              ext == 'ogg' ||
              ext == 'opus' ||
              ext == 'flac' ||
              ext == 'aac' ||
              ext == '3gp';
        })
        .map(RecordingClip.fromFile)
        .toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    _recordings = files;
    notifyListeners();
  }

  /// Records the current mic clip (gained PCM) into the persistent store.
  Future<void> storeRecording() async {
    if (_mic.isRecording) return;
    // Reuse the existing gained-PCM capture path.
    _mic.startRecording();
    notifyListeners();
  }

  Future<void> stopRecordingAndStore() async {
    if (!_mic.isRecording) return;
    final samples = _mic.stopRecording();
    if (samples.isEmpty) {
      notifyListeners();
      return;
    }
    final wavBytes = WavPcm16Encoder.encode(
      samples,
      frames: samples.length,
      sampleRate: MicAnalyzer.sampleRate,
      channels: 1,
    );
    final dirPath = await _recordingsDir();
    final DateTime now = DateTime.now();
    final String stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File('$dirPath/recording-$stamp.wav');
    await file.writeAsBytes(wavBytes);
    await refreshRecordings();
    notifyListeners();
  }

  Future<void> trimRecording(String path, double startSec, double endSec) async {
    try {
      final bytes = await File(path).readAsBytes();
      final info = readWavInfo(bytes);
      if (info == null || !info.isPcm) return;
      final blockAlign = info.blockAlign;
      final sampleRate = info.sampleRate;
      final startFrame = (startSec * sampleRate).round().clamp(0, info.frames);
      final endFrame = (endSec * sampleRate).round().clamp(startFrame, info.frames);
      if (endFrame <= startFrame) return;
      final startByte = info.dataOffset + startFrame * blockAlign;
      final endByte = info.dataOffset + endFrame * blockAlign;
      final pcm = Uint8List.sublistView(bytes, startByte, endByte);
      final out = buildPcmWav(
        pcm: pcm,
        sampleRate: sampleRate,
        channels: info.channels,
        bitsPerSample: info.bitsPerSample,
      );
      await File(path).writeAsBytes(out);
      await refreshRecordings();
      notifyListeners();
    } catch (e) {
      errorLog('[SoundFinderState] trim failed: $e');
    }
  }

  Future<void> normalizeRecording(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final info = readWavInfo(bytes);
      if (info == null || !info.isPcm || info.bitsPerSample != 16) return;
      final pcmBytes = bytes.sublist(info.dataOffset, info.dataOffset + info.dataLength);
      final bd = ByteData.sublistView(Uint8List.fromList(pcmBytes));
      int peak = 0;
      final sampleCount = info.dataLength ~/ 2;
      for (int i = 0; i < sampleCount; i++) {
        final v = bd.getInt16(i * 2, Endian.little).abs();
        if (v > peak) peak = v;
      }
      if (peak == 0) return;
      final scale = 32767.0 / peak * 0.95;
      final outPcm = Uint8List(info.dataLength);
      final outBd = ByteData.sublistView(outPcm);
      for (int i = 0; i < sampleCount; i++) {
        final v = (bd.getInt16(i * 2, Endian.little) * scale).round().clamp(-32768, 32767);
        outBd.setInt16(i * 2, v, Endian.little);
      }
      final out = buildPcmWav(
        pcm: outPcm,
        sampleRate: info.sampleRate,
        channels: info.channels,
        bitsPerSample: info.bitsPerSample,
      );
      await File(path).writeAsBytes(out);
      await refreshRecordings();
      notifyListeners();
    } catch (e) {
      errorLog('[SoundFinderState] normalize failed: $e');
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await refreshRecordings();
  }

  Future<Uint8List?> exportRecording(String path, SfRecordingFormat format) async {
    if (_recordingsExporting) return null;
    _recordingsExporting = true;
    notifyListeners();
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }
      final source = await SoLoud.instance.loadFile(path);
      final chunks = <Uint8List>[];
      final ended = Completer<void>();
      StreamSubscription<Uint8List>? captureSub;
      StreamSubscription<StreamSoundEvent>? endSub;
      try {
        final stream = SoLoud.instance.startMixerOutputStream(
          format: format.mixerFormat,
          sampleRate: 44100,
          channels: 2,
          chunkPCMFrames: format.isPcm ? 2048 : -1,
        );
        captureSub = stream.listen(chunks.add);
        final handle = SoLoud.instance.play(source, paused: true);
        endSub = source.soundEvents.listen((event) {
          if (event.handle == handle &&
              event.event == SoundEventType.handleIsNoMoreValid &&
              !ended.isCompleted) {
            ended.complete();
          }
        });
        SoLoud.instance.setPause(handle, false);
        // Estimate duration from file size (~44.1k 16-bit mono).
        double seconds = 5;
        try {
          final bytes = await File(path).readAsBytes();
          final info = readWavInfo(bytes);
          if (info != null && info.sampleRate > 0) {
            seconds = info.duration.inMilliseconds / 1000.0;
          }
        } catch (_) {}
        await ended.future.timeout(
          Duration(seconds: seconds.ceil() + 5),
          onTimeout: () => SoLoud.instance.stop(handle),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } finally {
        await endSub?.cancel();
        SoLoud.instance.stopMixerOutputStream();
        await captureSub?.cancel();
        await SoLoud.instance.disposeSource(source);
      }
      if (chunks.isEmpty) return null;
      final bytes = Uint8List(chunks.fold(0, (sum, c) => sum + c.length));
      int offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      if (!format.isPcm) return bytes;
      return buildPcmWav(
        pcm: bytes,
        sampleRate: 44100,
        channels: 2,
        bitsPerSample: 16,
      );
    } catch (e) {
      errorLog('[SoundFinderState] export recording failed: $e');
      return null;
    } finally {
      _recordingsExporting = false;
      notifyListeners();
    }
  }

  Future<void> startNormalRecording() async {
    errorLog('[SF] startNormalRecording called, diskRecording=$_diskRecording, micRunning=${_mic.isRunning}, status=$_micStatus');
    if (_diskRecording) return;
    if (_micStatus != MicStatus.running) {
      errorLog('[SF] startNormalRecording: mic not running');
      return;
    }
    _normalRecStart = DateTime.now();
    _mic.startRecording();
    _diskRecording = true;
    _diskWaveformSub = _mic.pcmStream.listen((chunk) {
      for (int i = 0; i < chunk.length; i++) {
        _diskWaveform[_diskWaveformPos % _diskWaveform.length] = chunk[i];
        _diskWaveformPos++;
      }
      notifyListeners();
    });
    _diskWaveform.fillRange(0, _diskWaveform.length, 0);
    _diskWaveformPos = 0;
    if (_maxRecordSeconds > 0) {
      _diskRecTimer = Timer(
        Duration(seconds: _maxRecordSeconds),
        () => unawaited(stopNormalRecordingAndStore()),
      );
    }
    notifyListeners();
  }

  Future<void> pauseNormalRecording() async {
    if (!_diskRecording) return;
    await _mic.pauseRecording();
    notifyListeners();
  }

  Future<void> resumeNormalRecording() async {
    if (!_diskRecording) return;
    await _mic.resumeRecording();
    notifyListeners();
  }

  Future<void> stopNormalRecordingAndStore() async {
    errorLog('[SF] stopNormalRecordingAndStore');
    if (!_diskRecording) return;
    _diskRecTimer?.cancel();
    _diskRecTimer = null;
    _diskWaveformSub?.cancel();
    _diskWaveformSub = null;
    final samples = _mic.stopRecording();
    _diskRecording = false;
    if (samples.isEmpty) {
      errorLog('[SF] no samples captured');
      await refreshRecordings();
      notifyListeners();
      return;
    }
    int captureRate = MicAnalyzer.sampleRate;
    final start = _normalRecStart;
    if (start != null) {
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      if (elapsedMs > 0) {
        final computed = (samples.length * 1000 / elapsedMs).round();
        if (computed >= 8000 && computed <= 192000) {
          captureRate = computed;
        }
      }
    }
    _normalRecStart = null;
    final wavBytes = WavPcm16Encoder.encode(
      samples,
      frames: samples.length,
      sampleRate: captureRate,
      channels: 1,
    );
    final dirPath = await _recordingsDir();
    final DateTime now = DateTime.now();
    final String stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File('$dirPath/recording-$stamp.wav');
    await file.writeAsBytes(wavBytes);
    errorLog('[SF] saved ${samples.length} samples to ${file.path}');
    await refreshRecordings();
    notifyListeners();
  }

  Future<void> playRecording(String path) async {
    if (_playingRecordingPath == path && _playingHandle != null) {
      await stopRecordingPlayback();
      return;
    }
    await stopRecordingPlayback();
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
    try {
      final source = await SoLoud.instance.loadFile(path);
      final handle = SoLoud.instance.play(source);
      SoLoud.instance.setRelativePlaySpeed(handle, _playbackSpeed);
      SoLoud.instance.setVolume(handle, _playbackVolume);
      _playingSource = source;
      _playingHandle = handle;
      _playbackPosition = Duration.zero;
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final h = _playingHandle;
        if (h == null) return;
        try {
          _playbackPosition = SoLoud.instance.getPosition(h);
          notifyListeners();
        } catch (_) {}
      });
      _playingRecordingPath = path;
      _playingEndSub = source.soundEvents.listen((event) {
        if (event.handle == handle &&
            event.event == SoundEventType.handleIsNoMoreValid) {
          unawaited(stopRecordingPlayback());
        }
      });
      notifyListeners();
    } catch (e) {
      errorLog('[SoundFinderState] play recording failed: $e');
    }
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    final handle = _playingHandle;
    if (handle != null) {
      SoLoud.instance.setRelativePlaySpeed(handle, speed);
    }
    notifyListeners();
  }

  void setPlaybackVolume(double volume) {
    _playbackVolume = volume.clamp(0.0, 1.0);
    final handle = _playingHandle;
    if (handle != null) {
      SoLoud.instance.setVolume(handle, _playbackVolume);
    }
    notifyListeners();
  }

  void seekPlayback(Duration position) {
    final handle = _playingHandle;
    if (handle == null) return;
    SoLoud.instance.seek(handle, position);
    _playbackPosition = position;
    notifyListeners();
  }

  Future<void> stopRecordingPlayback() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    await _playingEndSub?.cancel();
    _playingEndSub = null;
    final handle = _playingHandle;
    final source = _playingSource;
    _playingHandle = null;
    _playingSource = null;
    _playingRecordingPath = null;
    _playbackPosition = Duration.zero;
    if (handle != null) {
      await SoLoud.instance.stop(handle);
    }
    if (source != null) {
      await SoLoud.instance.disposeSource(source);
    }
    notifyListeners();
  }

  Future<void> cancelNormalRecording() async {
    if (!_diskRecording) return;
    _diskRecTimer?.cancel();
    _diskRecTimer = null;
    _diskWaveformSub?.cancel();
    _diskWaveformSub = null;
    _mic.stopRecording();
    _normalRecStart = null;
    _diskRecording = false;
    notifyListeners();
  }

  // --- Sleep sound recorder ---

  Future<String> _sleepDir() async {
    if (_sleepDirPath != null) return _sleepDirPath!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sleep_recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    _sleepDirPath = dir.path;
    return dir.path;
  }

  void setSleepDurationMinutes(int minutes) {
    if (_sleepActive) return;
    _sleepDurationMinutes = minutes.clamp(30, 720);
    notifyListeners();
  }

  void setSleepThreshold(double value) {
    _sleepThreshold = value.clamp(0.0005, 0.2);
    _save('sf_sleep_threshold', _sleepThreshold.toStringAsFixed(5));
    notifyListeners();
  }

  Future<void> startSleep() async {
    if (_sleepActive) return;
    _sleepError = null;
    _sleepSessionFiles.clear();
    // Disable processing effects for faithful capture.
    _noiseSuppress = false;
    _echoCancel = false;
    _autoGain = false;
    MicAnalyzer.noiseSuppress = false;
    MicAnalyzer.echoCancel = false;
    MicAnalyzer.autoGain = false;
    _micGain = 1.0;
    _mic.gain = 1.0;
    _mic.maxRecordSeconds = 0;

    if (_micStatus != MicStatus.running) {
      await ensureMic();
    } else {
      await _restartMic();
    }
    if (_micStatus != MicStatus.running) {
      _sleepError = 'Microphone not available.';
      notifyListeners();
      return;
    }

    _sleepActive = true;
    _sleepStart = DateTime.now();
    _sleepChunksKept = 0;
    _sleepSessionFiles.clear();
    _sleepLastEvent = null;
    final base = await getApplicationDocumentsDirectory();
    final stamp =
        '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}'
        '${DateTime.now().day.toString().padLeft(2, '0')}-'
        '${DateTime.now().hour.toString().padLeft(2, '0')}'
        '${DateTime.now().minute.toString().padLeft(2, '0')}'
        '${DateTime.now().second.toString().padLeft(2, '0')}';
    _sleepSessionDir = '${base.path}/sleep_recordings/session-$stamp';
    await Directory(_sleepSessionDir!).create(recursive: true);

    // Keep CPU awake but let the screen turn off.
    await PowerWakeLockService.releaseAll();
    _sleepWakeLock = await PowerWakeLockService.acquirePartial();

    _sleepTimeout = Timer(
      Duration(minutes: _sleepDurationMinutes),
      () => unawaited(stopSleep()),
    );

    _mic.startRecording();
    _scheduleSleepChunk();
    notifyListeners();
  }

  void _scheduleSleepChunk() {
    _sleepChunkTimer?.cancel();
    _sleepChunkTimer = Timer(const Duration(seconds: 60), () async {
      if (!_sleepActive) return;
      await _processSleepChunk();
      if (_sleepActive) {
        _mic.startRecording();
        _scheduleSleepChunk();
      }
    });
  }

  Future<void> _processSleepChunk() async {
    final samples = _mic.stopRecording();
    if (samples.isEmpty) {
      errorLog('[Sleep] chunk empty');
      return;
    }
    double maxAbs = 0;
    for (final s in samples) {
      final a = s.abs();
      if (a > maxAbs) maxAbs = a;
    }
    errorLog('[Sleep] chunk samples=${samples.length} maxAbs=$maxAbs');
    // Keep chunk only if it contains meaningful sound.
    if (maxAbs < _sleepThreshold) return;
    final dirPath = _sleepSessionDir ?? await _sleepDir();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File('$dirPath/chunk-$stamp.wav');
    final wavBytes = WavPcm16Encoder.encode(
      samples,
      frames: samples.length,
      sampleRate: _sampleRate,
      channels: 1,
    );
    await file.writeAsBytes(wavBytes);
    _sleepChunksKept++;
    _sleepSessionFiles.add(file.path);
    _sleepLastEvent = DateTime.now();
    notifyListeners();
  }

  Future<void> stopSleep() async {
    if (!_sleepActive) return;
    _sleepActive = false;
    _sleepTimeout?.cancel();
    _sleepTimeout = null;
    _sleepChunkTimer?.cancel();
    _sleepChunkTimer = null;
    await _processSleepChunk();
    _sleepStart = null;
    _mic.maxRecordSeconds = _maxRecordSeconds;
    final lease = _sleepWakeLock;
    _sleepWakeLock = null;
    if (lease != null) await lease.release();
    // Restore screen-on wake lock.
    await PowerWakeLockService.acquireFull();
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

  void _syncMicConfig() {
    MicAnalyzer.sampleRate = _sampleRate;
    MicAnalyzer.noiseSuppress = _noiseSuppress;
    MicAnalyzer.echoCancel = _echoCancel;
    MicAnalyzer.autoGain = _autoGain;
  }

  Future<void> _restartMic() async {
    await _mic.stop();
    _micStatus = MicStatus.idle;
    _syncMicConfig();
    final MicStartResult result = await _mic.start();
    _micStatus = switch (result) {
      MicStartResult.ok => MicStatus.running,
      MicStartResult.denied => MicStatus.denied,
      MicStartResult.unavailable => MicStatus.unavailable,
    };
  }

  void _onAnalysis(MicAnalysis a) {
    _analysis = a;
    if (_sleepActive) _sleepLiveDb = a.db;
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
    await cancelNormalRecording();
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
    if (_sleepActive) return;
    await cancelNormalRecording();
    await stopRecordingPlayback();
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
    if (_sleepActive) return; // keep recording
    if (_micStatus != MicStatus.running) return;
    await _mic.stop();
    _suspended = true;
  }

  /// App returned to foreground — resume the mic if it was suspended.
  Future<void> onAppForegrounded() async {
    if (_sleepActive) return;
    if (!_suspended) return;
    _suspended = false;
    if (_mode != SfMode.generator) {
      _syncMicConfig();
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

    _syncMicConfig();
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

      final int maxSamples = MicAnalyzer.sampleRate * 60;
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
    final maxRec = await db.getSetting(_toolId, _kMaxRecordSeconds);
    _maxRecordSeconds = int.tryParse(maxRec ?? '') ?? MicAnalyzer.defaultMaxRecordSeconds;
    _mic.maxRecordSeconds = _maxRecordSeconds;

    final sr = await db.getSetting(_toolId, 'sf_sample_rate');
    _sampleRate = int.tryParse(sr ?? '') ?? 44100;
    MicAnalyzer.sampleRate = _sampleRate;
    final ns = await db.getSetting(_toolId, 'sf_noise_suppress');
    _noiseSuppress = ns == 'true';
    MicAnalyzer.noiseSuppress = _noiseSuppress;
    final ec = await db.getSetting(_toolId, 'sf_echo_cancel');
    _echoCancel = ec == 'true';
    MicAnalyzer.echoCancel = _echoCancel;
    final ag = await db.getSetting(_toolId, 'sf_auto_gain');
    _autoGain = ag == 'true';
    MicAnalyzer.autoGain = _autoGain;

    final st = await db.getSetting(_toolId, 'sf_sleep_threshold');
    _sleepThreshold = double.tryParse(st ?? '') ?? 0.005;

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

  static Future<List<SleepSession>> listSleepSessions() async {
    final base = await getApplicationDocumentsDirectory();
    final root = Directory('${base.path}/sleep_recordings');
    if (!await root.exists()) return const [];
    final sessions = <SleepSession>[];
    for (final entity in root.listSync()) {
      if (entity is Directory) {
        final chunks = entity
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.wav'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        if (chunks.isNotEmpty) {
          sessions.add(SleepSession(path: entity.path, chunks: chunks));
        }
      }
    }
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  static Future<void> deleteSleepSession(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    _diskRecTimer?.cancel();
    _playbackTimer?.cancel();
    _diskWaveformSub?.cancel();
    _diskRecSink?.close();
    _playingEndSub?.cancel();
    _micSub?.cancel();
    _morsePcmSub?.cancel();
    _morseDecodeTimer?.cancel();
    _mic.dispose();
    _tone.dispose();
    super.dispose();
  }
}

class SleepSession {
  SleepSession({required this.path, required this.chunks});

  final String path;
  final List<File> chunks;

  String get name => path.split(Platform.pathSeparator).last;

  DateTime get createdAt {
    final parts = name.split('-');
    // session-YYYYMMDD-HHMMSS
    if (parts.length >= 3) {
      final d = parts[1];
      final t = parts[2];
      if (d.length == 8 && t.length == 6) {
        try {
          return DateTime(
            int.parse(d.substring(0, 4)),
            int.parse(d.substring(4, 6)),
            int.parse(d.substring(6, 8)),
            int.parse(t.substring(0, 2)),
            int.parse(t.substring(2, 4)),
            int.parse(t.substring(4, 6)),
          );
        } catch (_) {}
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Duration get totalDuration {
    // Estimate from file sizes at 16-bit mono default 44.1k (approx).
    int bytes = 0;
    for (final f in chunks) {
      bytes += f.lengthSync();
    }
    final samples = (bytes - chunks.length * 44) ~/ 2;
    return Duration(seconds: (samples / 44100).round());
  }
}

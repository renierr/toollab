import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'fft.dart';

enum MicStartResult { ok, denied, unavailable }

/// Spectrum detail presets. The bin resolution is `sampleRate / fftSize`
/// (a fundamental time–frequency tradeoff: finer bins need a longer window).
/// The hop is held constant across presets so the refresh rate stays ~10.8/s
/// regardless of window size — larger windows just overlap more.
enum SpectrumResolution {
  fast(8192, 4096), // ~5.4 Hz bins, 186 ms window, 50% overlap
  balanced(16384, 4096), // ~2.7 Hz bins, 372 ms window, 75% overlap
  fine(32768, 4096); // ~1.3 Hz bins, 743 ms window, 87.5% overlap

  const SpectrumResolution(this.fftSize, this.hop);

  final int fftSize;
  final int hop;

  double get binHz => MicAnalyzer.sampleRate / fftSize;
}

/// A single frame of microphone analysis.
class MicAnalysis {
  final double rms; // 0..1 linear loudness of the window
  final double db; // dBFS (<= 0), loudness proxy for the tracker
  final double peakFreqHz; // dominant frequency in the window
  final double peakLevel; // linear magnitude of the dominant bin
  final Float64List magnitudes; // full linear magnitude spectrum, one per bin
  final double binHz; // frequency width of a single bin

  const MicAnalysis({
    required this.rms,
    required this.db,
    required this.peakFreqHz,
    required this.peakLevel,
    required this.magnitudes,
    required this.binHz,
  });

  /// Highest frequency represented in [magnitudes] (the Nyquist frequency).
  double get maxFreqHz => binHz * magnitudes.length;

  factory MicAnalysis.zero() => MicAnalysis(
    rms: 0,
    db: -90,
    peakFreqHz: 0,
    peakLevel: 0,
    magnitudes: Float64List(0),
    binHz: 1,
  );
}

/// Captures raw, unfiltered microphone PCM and derives loudness + a frequency
/// spectrum from it. Auto-gain / echo / noise suppression are disabled so the
/// mic stays as sensitive and unprocessed as possible.
class MicAnalyzer {
  static const int sampleRate = 44100;
  static const double _minFreqHz = 20;

  /// Longest clip that can be captured into memory before recording auto-stops.
  static const int maxRecordSeconds = 60;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  // Analysis window. Configurable at runtime via [setResolution]; a larger
  // window yields finer frequency bins. The ring is refilled by [_hop] samples
  // between transforms (the rest is retained), so overlap = 1 - hop/fftSize.
  SpectrumResolution _resolution = SpectrumResolution.balanced;
  int _fftSize = SpectrumResolution.balanced.fftSize;
  int _hop = SpectrumResolution.balanced.hop;
  Float64List _ring = Float64List(SpectrumResolution.balanced.fftSize);
  int _filled = 0;

  SpectrumResolution get resolution => _resolution;

  /// Switches the analysis window. Safe to call while running — the in-flight
  /// partial window is discarded and the next frame uses the new size.
  void setResolution(SpectrumResolution r) {
    if (r == _resolution) return;
    _resolution = r;
    _fftSize = r.fftSize;
    _hop = r.hop;
    _ring = Float64List(_fftSize);
    _filled = 0;
  }

  // Clip recording: gained samples are accumulated in chunks and concatenated
  // on stop, capped at [maxRecordSeconds].
  static final int _maxRecordFrames = sampleRate * maxRecordSeconds;
  final List<Float32List> _recChunks = [];
  int _recFrames = 0;
  bool _recording = false;

  bool get isRecording => _recording;
  int get recordedFrames => _recFrames;
  double get recordedSeconds => _recFrames / sampleRate;

  /// Fires when a running recording hits [maxRecordSeconds] and auto-stops, so
  /// the UI can refresh without polling.
  VoidCallback? onRecordLimitReached;

  void startRecording() {
    _recChunks.clear();
    _recFrames = 0;
    _recording = true;
  }

  /// Stops recording and returns the captured mono samples (empty if nothing
  /// was captured). Safe to call when not recording.
  Float32List stopRecording() {
    _recording = false;
    final Float32List out = Float32List(_recFrames);
    int offset = 0;
    for (final Float32List chunk in _recChunks) {
      out.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _recChunks.clear();
    _recFrames = 0;
    return out;
  }

  void _appendRecording(Float32List chunk) {
    final int room = _maxRecordFrames - _recFrames;
    if (room <= 0) return;
    if (chunk.length <= room) {
      _recChunks.add(chunk);
      _recFrames += chunk.length;
    } else {
      _recChunks.add(Float32List.sublistView(chunk, 0, room));
      _recFrames += room;
      _recording = false;
      onRecordLimitReached?.call();
    }
  }

  /// Selected capture device. `null` follows the platform default mic.
  InputDevice? device;

  /// Linear gain applied to the raw PCM before analysis. 1.0 is unmodified;
  /// higher values boost quiet input at the cost of clipping loud peaks (the
  /// signal is clamped to the ±1.0 full-scale range). Applied in software since
  /// hardware auto-gain is intentionally disabled.
  double gain = 1.0;

  /// Enumerates the available capture devices (built-in, wired, USB, Bluetooth
  /// SCO on Android; WASAPI capture endpoints on Windows). Returns empty on
  /// platforms/permissions that do not expose device lists.
  Future<List<InputDevice>> listInputDevices() async {
    try {
      return await _recorder.listInputDevices();
    } catch (e) {
      errorLog('[MicAnalyzer] listInputDevices failed: $e');
      return const [];
    }
  }

  final StreamController<MicAnalysis> _controller =
      StreamController<MicAnalysis>.broadcast();
  Stream<MicAnalysis> get stream => _controller.stream;

  final StreamController<Float32List> _pcmController =
      StreamController<Float32List>.broadcast();
  Stream<Float32List> get pcmStream => _pcmController.stream;

  bool _running = false;
  bool get isRunning => _running;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<MicStartResult> start() async {
    if (_running) return MicStartResult.ok;

    bool granted;
    try {
      granted = await _recorder.hasPermission();
    } catch (e) {
      errorLog('[MicAnalyzer] permission check failed: $e');
      return MicStartResult.unavailable;
    }
    if (!granted) return MicStartResult.denied;

    try {
      final Stream<Uint8List> stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          device: device,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      _filled = 0;
      _sub = stream.listen(
        _onData,
        onError: (Object e) => errorLog('[MicAnalyzer] stream error: $e'),
      );
      _running = true;
      return MicStartResult.ok;
    } catch (e) {
      errorLog('[MicAnalyzer] start failed: $e');
      return MicStartResult.unavailable;
    }
  }

  void _onData(Uint8List bytes) {
    final int count = bytes.length ~/ 2;
    final ByteData view = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      count * 2,
    );
    final double g = gain;
    final bool pcmListeners = _pcmController.hasListener;
    final Float32List? rec = (_recording || pcmListeners)
        ? Float32List(count)
        : null;
    for (int i = 0; i < count; i++) {
      final double sample = view.getInt16(i * 2, Endian.little) / 32768.0;
      final double v = g == 1.0 ? sample : (sample * g).clamp(-1.0, 1.0);
      _ring[_filled] = v;
      if (rec != null) rec[i] = v;
      _filled++;
      if (_filled == _fftSize) {
        _analyze();
        // Slide the window: keep everything past the newest [_hop] samples.
        _ring.setRange(0, _fftSize - _hop, _ring, _hop);
        _filled = _fftSize - _hop;
      }
    }
    if (rec != null) {
      if (_recording) _appendRecording(rec);
      if (pcmListeners) _pcmController.add(rec);
    }
  }

  void _analyze() {
    final SpectrumResult spec = Fft.magnitudeSpectrum(
      Float64List.fromList(_ring),
      sampleRate,
    );
    final Float64List mags = spec.magnitudes;

    double sumSq = 0;
    for (int i = 0; i < _fftSize; i++) {
      sumSq += _ring[i] * _ring[i];
    }
    final double rms = math.sqrt(sumSq / _fftSize);
    final double db = rms > 1e-7 ? 20 * (math.log(rms) / math.ln10) : -90.0;

    final int minBin = math.max(1, (_minFreqHz / spec.binHz).floor());
    int peakIdx = minBin;
    double peakVal = 0;
    for (int i = minBin; i < mags.length; i++) {
      if (mags[i] > peakVal) {
        peakVal = mags[i];
        peakIdx = i;
      }
    }

    // Parabolic interpolation around the peak for sub-bin frequency accuracy.
    double peakFreq = peakIdx * spec.binHz;
    if (peakIdx > 0 && peakIdx < mags.length - 1) {
      final double a = mags[peakIdx - 1];
      final double b = mags[peakIdx];
      final double c = mags[peakIdx + 1];
      final double denom = a - 2 * b + c;
      if (denom != 0) {
        peakFreq = (peakIdx + 0.5 * (a - c) / denom) * spec.binHz;
      }
    }

    _controller.add(
      MicAnalysis(
        rms: rms,
        db: db,
        peakFreqHz: peakFreq,
        peakLevel: peakVal,
        magnitudes: mags,
        binHz: spec.binHz,
      ),
    );
  }

  Future<void> stop() async {
    _running = false;
    _recording = false;
    _recChunks.clear();
    _recFrames = 0;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _recorder.dispose();
    } catch (_) {}
    await _controller.close();
    await _pcmController.close();
  }
}

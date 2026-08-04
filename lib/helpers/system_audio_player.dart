import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Waveform + spectrum snapshot captured from the Android output mix.
class SystemAudioSpectrum {
  /// 256 FFT magnitudes, 0.0 – 1.0.
  final List<double> freq;

  /// 256 waveform samples, -1.0 – 1.0.
  final List<double> wave;

  /// Average energy of the lowest 16 bins, 0.0 – 1.0.
  final double bass;

  const SystemAudioSpectrum({
    required this.freq,
    required this.wave,
    required this.bass,
  });
}

/// One tick pushed by the native player while a track is loaded.
class SystemAudioEvent {
  final Duration position;
  final bool completed;
  final String? error;
  final SystemAudioSpectrum? spectrum;

  const SystemAudioEvent({
    required this.position,
    required this.completed,
    this.error,
    this.spectrum,
  });
}

/// Plays audio through Android's own codecs (MediaPlayer) while ToolLab keeps
/// driving the UI, so formats no bundled decoder handles — aac, m4a, opus, wma,
/// mka … — play inside the app instead of in an external player activity.
class SystemAudioPlayer {
  SystemAudioPlayer._();

  static final SystemAudioPlayer instance = SystemAudioPlayer._();

  static const String _logPrefix = '[SystemAudioPlayer]';
  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/system_audio',
  );
  static const EventChannel _events = EventChannel(
    'de.renier.tool_lab/system_audio_events',
  );

  /// Number of FFT bins / waveform samples handed to the visualizer.
  static const int _binCount = 256;

  static bool get isSupported => Platform.isAndroid;

  Stream<SystemAudioEvent>? _stream;

  /// True when the last [load] could attach output capture, so [events] carry
  /// visualizer data. Capture needs the microphone permission.
  bool get hasSpectrum => _hasSpectrum;
  bool _hasSpectrum = false;

  /// Position / end-of-stream ticks from the native player, roughly every 60 ms
  /// while playing.
  Stream<SystemAudioEvent> get events {
    return _stream ??= _events
        .receiveBroadcastStream()
        .map(_decodeEvent)
        .where((event) => event != null)
        .cast<SystemAudioEvent>();
  }

  /// Prepares [path] for playback. Returns its duration, or `null` when the
  /// system codecs cannot open the file (callers should fall back).
  Future<Duration?> load(String path, String mimeType) async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('load', {
        'path': path,
        'mimeType': mimeType,
      });
      if (result == null) return null;
      _hasSpectrum = result['visualizer'] == true;
      final ms = (result['durationMs'] as num?)?.toInt() ?? 0;
      return Duration(milliseconds: ms);
    } catch (e) {
      debugPrint('$_logPrefix load failed: $e');
      _hasSpectrum = false;
      return null;
    }
  }

  /// Starts playback and reports whether Android accepted the prepared source.
  /// Unlike non-critical controls, callers must know when this fails so they do
  /// not show a playing state with no audible output.
  Future<bool> play() async {
    if (!isSupported) return false;
    try {
      await _channel.invokeMethod<void>('play');
      return true;
    } catch (e) {
      debugPrint('$_logPrefix play failed: $e');
      return false;
    }
  }

  Future<void> pause() => _invoke('pause');

  /// Pauses and rewinds; the source stays prepared so [play] restarts it.
  Future<void> stop() => _invoke('stop');

  Future<void> seek(Duration position) => _invoke('seek', {
    'positionMs': position.inMilliseconds < 0 ? 0 : position.inMilliseconds,
  });

  Future<void> setVolume(double volume) =>
      _invoke('setVolume', {'volume': volume.clamp(0.0, 1.0)});

  Future<void> setLooping(bool looping) =>
      _invoke('setLooping', {'looping': looping});

  Future<void> release() {
    _hasSpectrum = false;
    return _invoke('release');
  }

  Future<bool> hasCapturePermission() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasCapturePermission') ?? false;
  }

  /// Asks for the microphone permission the Android [Visualizer] effect requires
  /// to read the app's own output. Denied is fine — playback then runs without
  /// visualizer data.
  Future<bool> requestCapturePermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestCapturePermission') ??
          false;
    } catch (e) {
      debugPrint('$_logPrefix permission request failed: $e');
      return false;
    }
  }

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('$_logPrefix $method failed: $e');
    }
  }

  static SystemAudioEvent? _decodeEvent(Object? raw) {
    if (raw is! Map) return null;
    final positionMs = (raw['positionMs'] as num?)?.toInt() ?? 0;
    final completed = raw['completed'] == true;
    return SystemAudioEvent(
      position: Duration(milliseconds: positionMs),
      completed: completed,
      error: raw['error'] as String?,
      spectrum: _decodeSpectrum(
        raw['wave'] as Uint8List?,
        raw['fft'] as Uint8List?,
      ),
    );
  }

  /// Converts the raw [Visualizer] buffers: waveform bytes are unsigned 8-bit
  /// PCM centred on 128, FFT bytes are signed real/imaginary pairs.
  static SystemAudioSpectrum? _decodeSpectrum(Uint8List? wave, Uint8List? fft) {
    if (wave == null && fft == null) return null;

    final waveOut = List<double>.filled(_binCount, 0);
    if (wave != null && wave.isNotEmpty) {
      for (int i = 0; i < _binCount; i++) {
        final src = (i * wave.length) ~/ _binCount;
        waveOut[i] = (wave[src] - 128) / 128.0;
      }
    }

    final freqOut = List<double>.filled(_binCount, 0);
    double bassSum = 0;
    if (fft != null && fft.length >= 4) {
      final int pairs = fft.length ~/ 2;
      // Magnitudes are normalised against a byte pair's maximum (~181) and
      // curved so quiet bins stay visible, matching the module path's feel.
      for (int i = 0; i < _binCount; i++) {
        final pair = (i * pairs) ~/ _binCount;
        final real = fft[pair * 2].toSigned(8);
        final imaginary = fft[pair * 2 + 1].toSigned(8);
        final magnitude = math.sqrt(
          (real * real + imaginary * imaginary).toDouble(),
        );
        final value = math
            .pow(magnitude / 181.0, 0.5)
            .toDouble()
            .clamp(0.0, 1.0);
        freqOut[i] = value;
        if (i < 16) bassSum += value;
      }
    }

    return SystemAudioSpectrum(
      freq: freqOut,
      wave: waveOut,
      bass: bassSum / 16,
    );
  }
}

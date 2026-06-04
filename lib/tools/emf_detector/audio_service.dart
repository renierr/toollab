import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioService {
  AudioSource? _audioSource;
  bool _initialized = false;
  bool _isEnabled = false;

  Timer? _tickerTimer;
  double _currentIntervalMs = 0.0;

  AudioService() {
    _initSoundFile();
  }

  bool get isEnabled => _isEnabled;

  /// Enable or disable beep sounds.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!_isEnabled) {
      _tickerTimer?.cancel();
      _tickerTimer = null;
    }
  }

  /// Synthesizes a Geiger-counter click WAV file in-memory and loads it into SoLoud.
  Future<void> _initSoundFile() async {
    try {
      // 1. Initialize the SoLoud engine if it isn't already initialized
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }

      // Wave file properties: 16-bit PCM at 48kHz with a 200ms duration.
      // A longer duration (200ms vs 20ms) satisfies native OS media player buffer size requirements
      // and warm-up latencies, preventing silent playbacks.
      // We use 48,000 Hz sample rate to match the standard native Windows mixing rate of SoLoud.
      const int sampleRate = 48000;
      const int numSamples =
          9600; // 48000 * 0.2 = 9600 samples (200ms click duration)
      const int bitsPerSample = 16;
      const int blockAlign = 2; // 1 channel * 16 bits / 8 = 2 bytes
      const int byteRate = sampleRate * blockAlign; // 96000 bytes/sec
      const int subchunk2size =
          numSamples * blockAlign; // 19200 bytes of PCM data
      final int fileSize = 36 + subchunk2size; // 19236 bytes total file size

      final List<int> wavBytes = [];

      // WAV Header
      // 1. RIFF Identifier
      wavBytes.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
      // 2. Size (36 + subchunk2size)
      wavBytes.addAll([
        fileSize & 0xFF,
        (fileSize >> 8) & 0xFF,
        (fileSize >> 16) & 0xFF,
        (fileSize >> 24) & 0xFF,
      ]);
      // 3. Format
      wavBytes.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"

      // Subchunk 1 (fmt)
      wavBytes.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
      wavBytes.addAll([16, 0, 0, 0]); // Subchunk1Size = 16
      wavBytes.addAll([1, 0]); // AudioFormat = 1 (PCM)
      wavBytes.addAll([1, 0]); // NumChannels = 1 (Mono)
      // SampleRate (48000)
      wavBytes.addAll([
        sampleRate & 0xFF,
        (sampleRate >> 8) & 0xFF,
        (sampleRate >> 16) & 0xFF,
        (sampleRate >> 24) & 0xFF,
      ]);
      // ByteRate (96000)
      wavBytes.addAll([
        byteRate & 0xFF,
        (byteRate >> 8) & 0xFF,
        (byteRate >> 16) & 0xFF,
        (byteRate >> 24) & 0xFF,
      ]);
      wavBytes.addAll([blockAlign, 0]); // BlockAlign = 2
      wavBytes.addAll([bitsPerSample, 0]); // BitsPerSample = 16

      // Subchunk 2 (data)
      wavBytes.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
      wavBytes.addAll([
        subchunk2size & 0xFF,
        (subchunk2size >> 8) & 0xFF,
        (subchunk2size >> 16) & 0xFF,
        (subchunk2size >> 24) & 0xFF,
      ]);

      // Sound generation: High pitch Geiger tick (sine wave with steep exponential decay envelope)
      const double frequency = 1800.0; // 1.8 kHz sharp beep
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        // Exponential decay envelope makes it sound like a tight "tick"
        final double envelope = exp(-t * 220.0);
        final double sine = sin(2 * pi * frequency * t);

        // Convert to 16-bit signed integer [-32768, 32767]
        final int sampleVal = (32767 * envelope * sine).round().clamp(
          -32768,
          32767,
        );

        // Write little-endian bytes
        wavBytes.add(sampleVal & 0xFF);
        wavBytes.add((sampleVal >> 8) & 0xFF);
      }

      final byteData = Uint8List.fromList(wavBytes);
      debugPrint(
        '[AudioService] Geiger-click WAV successfully synthesized in-memory. Bytes: ${byteData.length}',
      );

      // Load sound into SoLoud audio engine directly from memory
      _audioSource = await SoLoud.instance.loadMem(
        'emf_geiger_tick.wav',
        byteData,
      );
      _initialized = true;
      debugPrint(
        '[AudioService] SoLoud successfully loaded WAV from memory: $_audioSource',
      );
    } catch (e) {
      debugPrint('[AudioService] Failed to initialize SoLoud sound file: $e');
    }
  }

  /// Triggers a single instant tick sound.
  Future<void> playTick() async {
    if (!_initialized || _audioSource == null) return;
    try {
      SoLoud.instance.play(_audioSource!);
    } catch (e) {
      debugPrint('[AudioService] Error playing click sound: $e');
    }
  }

  /// Dynamically updates the beeper interval based on the current EMF delta reading
  /// relative to the warning threshold.
  ///
  /// - Below 5 uT: No beep (silent background)
  /// - 5 uT to Threshold: Slow pacing ticks (from 1.5 seconds down to 300ms)
  /// - Above Threshold: Rapid alarm-like ticking (from 300ms down to 45ms)
  void updateSignalStrength(double deltaMag, double threshold) {
    if (!_isEnabled || !_initialized) {
      return;
    }

    if (deltaMag < 4.0) {
      // Too weak to beep, stop the timer
      if (_tickerTimer != null) {
        _tickerTimer?.cancel();
        _tickerTimer = null;
      }
      return;
    }

    double intervalMs;

    if (deltaMag >= threshold) {
      // High alarm range
      // Map magnitude from [threshold, threshold + 100] to [300ms, 45ms]
      final overRatio = ((deltaMag - threshold) / 100.0).clamp(0.0, 1.0);
      intervalMs = 300.0 - (overRatio * 255.0); // Minimum 45ms interval
    } else {
      // Warning/approaching range [4.0, threshold]
      final rangeRatio = ((deltaMag - 4.0) / (threshold - 4.0)).clamp(0.0, 1.0);
      intervalMs = 1500.0 - (rangeRatio * 1200.0); // Down to 300ms
    }

    // Only restart timer if the target interval changed significantly to prevent ticker spam
    if ((intervalMs - _currentIntervalMs).abs() > 15.0 ||
        _tickerTimer == null) {
      _currentIntervalMs = intervalMs;
      _startTickerLoop();
    }
  }

  void _startTickerLoop() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(
      Duration(milliseconds: _currentIntervalMs.round()),
      (timer) {
        if (!_isEnabled) {
          timer.cancel();
          return;
        }
        playTick();
      },
    );
  }

  void dispose() {
    _tickerTimer?.cancel();
    if (_audioSource != null) {
      SoLoud.instance.disposeSource(_audioSource!);
    }
  }
}

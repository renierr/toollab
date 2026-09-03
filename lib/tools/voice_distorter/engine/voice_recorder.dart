import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../../helpers/debug_log.dart';
import '../../../helpers/temp_file_manager.dart';

enum RecordStartResult { ok, denied, unavailable }

/// Records a short voice clip straight to a WAV file via [AudioRecorder],
/// auto-stopping at [maxSeconds] so clips stay small.
class VoiceRecorder {
  static const int sampleRate = 44100;
  static const int maxSeconds = 15;

  final AudioRecorder _recorder = AudioRecorder();
  final TempFileScope _scope;

  VoiceRecorder(this._scope);

  bool _recording = false;
  bool get isRecording => _recording;

  Timer? _limitTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;

  /// Fires when recording auto-stops after [maxSeconds].
  VoidCallback? onLimitReached;

  /// Linear-ish amplitude (dBFS from `record`, normalized to 0..1) while
  /// recording, for a live level indicator.
  final ValueNotifier<double> level = ValueNotifier(0);

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<RecordStartResult> start() async {
    if (_recording) return RecordStartResult.ok;

    bool granted;
    try {
      granted = await _recorder.hasPermission();
    } catch (e) {
      errorLog('[VoiceRecorder] permission check failed: $e');
      return RecordStartResult.unavailable;
    }
    if (!granted) return RecordStartResult.denied;

    try {
      final String path = await _scope.createFile('voice_clip.wav');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
        path: path,
      );
      _recording = true;
      level.value = 0;
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            // dBFS, roughly -45..0 for speech; normalize for a level meter.
            level.value = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          });
      _limitTimer?.cancel();
      _limitTimer = Timer(const Duration(seconds: maxSeconds), () async {
        if (!_recording) return;
        await stop();
        onLimitReached?.call();
      });
      return RecordStartResult.ok;
    } catch (e) {
      errorLog('[VoiceRecorder] start failed: $e');
      return RecordStartResult.unavailable;
    }
  }

  /// Stops recording and returns the recorded clip's file path, or `null` if
  /// nothing was captured.
  Future<String?> stop() async {
    if (!_recording) return null;
    _recording = false;
    _limitTimer?.cancel();
    _limitTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    level.value = 0;
    try {
      return await _recorder.stop();
    } catch (e) {
      errorLog('[VoiceRecorder] stop failed: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _limitTimer?.cancel();
    await _amplitudeSub?.cancel();
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    await _recorder.dispose();
    level.dispose();
  }
}

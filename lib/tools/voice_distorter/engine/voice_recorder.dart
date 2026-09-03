import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../../helpers/debug_log.dart';
import '../../../helpers/temp_file_manager.dart';
import 'wav_utils.dart';

enum RecordStartResult { ok, denied, unavailable }

/// A finished recording. [isStereo] is only true when the file is known to hold
/// two channels — filters that require stereo must stay off otherwise.
/// [duration] is null when the file's header could not be read.
typedef VoiceClip = ({String path, bool isStereo, Duration? duration});

/// Records a short voice clip straight to a WAV file via [AudioRecorder],
/// auto-stopping at [maxSeconds] so clips stay small.
class VoiceRecorder {
  static const int sampleRate = 44100;
  static const int maxSeconds = 15;
  static const String _clipFile = 'voice_clip.wav';
  static const String _stereoFile = 'voice_clip_stereo.wav';

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
      final String path = await _scope.createFile(_clipFile);
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

  /// Stops recording and returns the captured clip, or `null` if nothing was
  /// captured. Capture is mono for device compatibility; the returned clip is
  /// widened to stereo so the reverb filter can run on it.
  Future<VoiceClip?> stop() async {
    if (!_recording) return null;
    _recording = false;
    _limitTimer?.cancel();
    _limitTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    level.value = 0;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      errorLog('[VoiceRecorder] stop failed: $e');
      return null;
    }
    if (path == null) return null;

    try {
      final Uint8List raw = await _scope.readFile(_clipFile);
      final WavInfo? info = readWavInfo(raw);
      final Duration? duration = info?.duration;
      debugLog(
        '[VoiceRecorder] captured ${raw.length} bytes, '
        '${info?.channels}ch ${info?.frames} frames, $duration',
      );
      final Uint8List? stereo = widenWavToStereo(raw);
      if (stereo != null) {
        final String out = await _scope.createFile(_stereoFile, bytes: stereo);
        return (path: out, isStereo: true, duration: duration);
      }
      return (path: path, isStereo: false, duration: duration);
    } catch (e) {
      errorLog('[VoiceRecorder] stereo conversion failed: $e');
      return (path: path, isStereo: false, duration: null);
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

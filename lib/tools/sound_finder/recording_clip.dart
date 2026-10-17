import 'dart:io';

import 'package:tool_lab/tools/voice_distorter/engine/wav_utils.dart';

/// A stored microphone recording on disk.
class RecordingClip {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  const RecordingClip({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  /// Duration read from the WAV header so it stays correct regardless of the
  /// capture sample rate.
  double get durationSeconds {
    if (sizeBytes <= 44) return 0;
    try {
      final bytes = File(path).readAsBytesSync();
      final info = readWavInfo(bytes);
      if (info != null && info.sampleRate > 0) {
        return info.duration.inMilliseconds / 1000.0;
      }
    } catch (_) {}
    return (sizeBytes - 44) / 2 / 44100.0;
  }

  factory RecordingClip.fromFile(File file) {
    final stat = file.statSync();
    return RecordingClip(
      path: file.path,
      name: file.uri.pathSegments.last,
      sizeBytes: stat.size,
      modified: stat.modified,
    );
  }
}

import 'dart:io';

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

  /// Best-effort duration from a 16-bit mono 44.1 kHz WAV container.
  double get durationSeconds {
    if (sizeBytes <= 44) return 0;
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

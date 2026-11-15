import 'dart:typed_data';

/// Remembers where each video was left; the player reads and writes it.
abstract interface class VideoResumeStore {
  /// Null when the video should start from the beginning.
  Future<Duration?> resumePosition(Uri source);

  Future<void> savePosition({
    required Uri source,
    required String title,
    required Duration position,
    required Duration duration,
  });

  /// A small JPEG of the frame where the video was left.
  Future<void> saveThumbnail(Uri source, Uint8List jpeg);
}

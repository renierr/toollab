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
}

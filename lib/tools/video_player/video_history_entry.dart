/// A video played in the ToolLab player and where it was left.
class VideoHistoryEntry {
  final String source;
  final String title;
  final int positionMs;
  final int durationMs;
  final int playedAt;

  const VideoHistoryEntry({
    required this.source,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.playedAt,
  });

  factory VideoHistoryEntry.fromMap(Map<String, Object?> map) =>
      VideoHistoryEntry(
        source: map['source'] as String,
        title: map['title'] as String,
        positionMs: map['position_ms'] as int,
        durationMs: map['duration_ms'] as int,
        playedAt: map['played_at'] as int,
      );

  Map<String, Object?> toMap() => {
    'source': source,
    'title': title,
    'position_ms': positionMs,
    'duration_ms': durationMs,
    'played_at': playedAt,
  };

  Uri get uri => Uri.parse(source);
  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);
  double get progress =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0;

  /// Close enough to the end that resuming would only show the credits.
  bool get finished =>
      durationMs > 0 && (durationMs - positionMs < 15000 || progress > 0.97);

  /// Worth offering a resume: started, not finished.
  bool get resumable => positionMs >= 5000 && !finished;
}

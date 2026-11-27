import 'trimz_series.dart';

/// A series the viewer watched or put on their list, with where they left it.
class TrimzSavedSeries {
  static const Duration _endSlack = Duration(seconds: 3);

  final String id;
  final String slug;
  final String title;
  final String? posterUrl;
  final int episodeCount;
  final int episodeIndex;
  final int positionMs;
  final int durationMs;

  /// Null when the series was only put on the list.
  final int? watchedAt;

  /// Null when the series is not on the list.
  final int? savedAt;

  const TrimzSavedSeries({
    required this.id,
    required this.slug,
    required this.title,
    this.posterUrl,
    this.episodeCount = 0,
    this.episodeIndex = 0,
    this.positionMs = 0,
    this.durationMs = 0,
    this.watchedAt,
    this.savedAt,
  });

  factory TrimzSavedSeries.fromMap(Map<String, Object?> map) =>
      TrimzSavedSeries(
        id: map['id']! as String,
        slug: map['slug']! as String,
        title: map['title']! as String,
        posterUrl: map['poster_url'] as String?,
        episodeCount: map['episode_count'] as int? ?? 0,
        episodeIndex: map['episode_index'] as int? ?? 0,
        positionMs: map['position_ms'] as int? ?? 0,
        durationMs: map['duration_ms'] as int? ?? 0,
        watchedAt: map['watched_at'] as int?,
        savedAt: map['saved_at'] as int?,
      );

  factory TrimzSavedSeries.of(TrimzSeries series) => TrimzSavedSeries(
    id: series.id,
    slug: series.slug,
    title: series.title,
    posterUrl: series.posterUrl,
    episodeCount: series.episodeCount,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'slug': slug,
    'title': title,
    'poster_url': posterUrl,
    'episode_count': episodeCount,
    'episode_index': episodeIndex,
    'position_ms': positionMs,
    'duration_ms': durationMs,
    'watched_at': watchedAt,
    'saved_at': savedAt,
  };

  bool get watched => watchedAt != null;
  bool get onList => savedAt != null;

  Duration get position => Duration(milliseconds: positionMs);

  /// The episode was played to its end.
  bool get episodeFinished =>
      durationMs > 0 &&
      Duration(milliseconds: durationMs - positionMs) <= _endSlack;

  /// Where "continue" starts: the next episode once this one is finished.
  int nextIndex(int count) {
    final next = episodeFinished ? episodeIndex + 1 : episodeIndex;
    return next.clamp(0, count > 0 ? count - 1 : 0);
  }

  /// The position to resume episode [index] at, if it is the one left off.
  Duration? resumeAt(int index) =>
      index == episodeIndex && !episodeFinished && position > _endSlack
      ? position
      : null;

  TrimzSeries toSeries() => TrimzSeries(
    id: id,
    slug: slug,
    title: title,
    posterUrl: posterUrl,
    episodeCount: episodeCount,
  );

  TrimzSavedSeries copyWith({
    String? title,
    String? posterUrl,
    int? episodeCount,
    int? episodeIndex,
    int? positionMs,
    int? durationMs,
    int? Function()? watchedAt,
    int? Function()? savedAt,
  }) => TrimzSavedSeries(
    id: id,
    slug: slug,
    title: title ?? this.title,
    posterUrl: posterUrl ?? this.posterUrl,
    episodeCount: episodeCount ?? this.episodeCount,
    episodeIndex: episodeIndex ?? this.episodeIndex,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    watchedAt: watchedAt == null ? this.watchedAt : watchedAt(),
    savedAt: savedAt == null ? this.savedAt : savedAt(),
  );
}

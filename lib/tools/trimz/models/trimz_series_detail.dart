import 'trimz_episode.dart';

/// A series with its episodes, as its watch page loads it.
class TrimzSeriesDetail {
  final String id;
  final String slug;
  final String title;
  final String? summary;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? thumbnailUrl;
  final int views;
  final int watchlistCount;
  final List<TrimzEpisode> episodes;

  const TrimzSeriesDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.episodes,
    this.summary,
    this.ownerName,
    this.ownerAvatarUrl,
    this.thumbnailUrl,
    this.views = 0,
    this.watchlistCount = 0,
  });

  factory TrimzSeriesDetail.fromJson(Map<String, dynamic> json) {
    final videos = json['videos'];
    final episodes = <TrimzEpisode>[
      if (videos is List)
        for (final video in videos.whereType<Map<String, dynamic>>())
          ?TrimzEpisode.tryParse(video),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return TrimzSeriesDetail(
      id: json['projectId'] as String,
      slug: json['slug'] as String? ?? '',
      title: _text(json['localizedTitle']) ?? json['title'] as String? ?? '',
      summary: _text(json['localizedSummary']) ?? _text(json['summary']),
      ownerName:
          _text(json['ownerDisplayName']) ?? _text(json['ownerUsername']),
      ownerAvatarUrl: _text(json['ownerProfilePictureUrl']),
      thumbnailUrl: _text(json['shareThumbnailUrl']),
      views: (json['totalViews'] as num?)?.toInt() ?? 0,
      watchlistCount: (json['watchlistCount'] as num?)?.toInt() ?? 0,
      episodes: episodes,
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  Duration get runtime =>
      episodes.fold(Duration.zero, (sum, e) => sum + e.duration);
}

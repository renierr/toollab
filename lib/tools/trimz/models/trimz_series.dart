/// A series as the catalog lists it.
class TrimzSeries {
  final String id;
  final String slug;
  final String title;
  final String? summary;
  final String? posterUrl;
  final String? ownerName;
  final int episodeCount;
  final int views;
  final String? badge;

  const TrimzSeries({
    required this.id,
    required this.slug,
    required this.title,
    this.summary,
    this.posterUrl,
    this.ownerName,
    this.episodeCount = 0,
    this.views = 0,
    this.badge,
  });

  factory TrimzSeries.fromJson(Map<String, dynamic> json) {
    final badges = json['card_badges'];
    final badge = badges is List && badges.isNotEmpty && badges.first is Map
        ? (badges.first as Map)['text'] as String?
        : null;
    return TrimzSeries(
      id: json['project_id'] as String,
      slug: json['slug'] as String? ?? '',
      title: _text(json['localized_title']) ?? json['title'] as String? ?? '',
      summary: _text(json['summary']),
      posterUrl: _text(json['poster_16_9_url']) ?? _text(json['poster_url']),
      ownerName:
          _text(json['owner_display_name']) ?? _text(json['owner_username']),
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      views: (json['total_views'] as num?)?.toInt() ?? 0,
      badge: badge,
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  Uri get webUrl => Uri.https('trimz.tv', '/$slug');
}

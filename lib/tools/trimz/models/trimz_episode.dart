class TrimzEpisode {
  final String id;
  final int order;
  final Uri? mp4;
  final Uri? hls;
  final String? posterUrl;
  final Duration duration;
  final bool sensitive;

  const TrimzEpisode({
    required this.id,
    required this.order,
    this.mp4,
    this.hls,
    this.posterUrl,
    this.duration = Duration.zero,
    this.sensitive = false,
  });

  /// Null for an episode without a playable video, e.g. one behind a paywall.
  static TrimzEpisode? tryParse(Map<String, dynamic> json) {
    final mp4 = _uri(json['url']);
    final hls = _uri(json['muxPlaybackUrl']);
    final id = json['shotId'];
    if (id is! String || (mp4 == null && hls == null)) return null;
    final seconds = (json['durationSec'] as num?)?.toDouble() ?? 0;
    return TrimzEpisode(
      id: id,
      order: (json['order'] as num?)?.toInt() ?? 0,
      mp4: mp4,
      hls: hls,
      posterUrl: json['poster'] as String?,
      duration: Duration(milliseconds: (seconds * 1000).round()),
      sensitive: json['sensitive'] != null,
    );
  }

  static Uri? _uri(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.isScheme('https') ? uri : null;
  }

  /// [adaptive] prefers the HLS stream, otherwise the original MP4.
  Uri source({required bool adaptive}) => (adaptive ? hls ?? mp4 : mp4 ?? hls)!;
}

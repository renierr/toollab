enum XBroadcastState { live, ended, upcoming, unknown }

/// A live video (`x.com/i/broadcasts/<id>`) attached to a post.
class XBroadcast {
  final String id;
  final String? title;
  final String? imageUrl;

  /// As of when the post was fetched; the stream request reports it fresh.
  final XBroadcastState state;

  const XBroadcast({
    required this.id,
    this.title,
    this.imageUrl,
    this.state = XBroadcastState.unknown,
  });

  static final RegExp _url = RegExp(
    r'^https?://(?:[\w-]+\.)?(?:x|twitter)\.com/i/broadcasts/(\w+)',
  );

  static String? idFromUrl(String? url) =>
      url == null ? null : _url.firstMatch(url)?.group(1);

  /// X's `RUNNING` / `ENDED` / `TIMED_OUT` / `NOT_STARTED`, any case.
  static XBroadcastState parseState(String? value) =>
      switch (value?.toUpperCase()) {
        'RUNNING' => XBroadcastState.live,
        'ENDED' || 'TIMED_OUT' => XBroadcastState.ended,
        'NOT_STARTED' || 'CREATED' => XBroadcastState.upcoming,
        _ => XBroadcastState.unknown,
      };
}

/// What the player needs: the HLS master playlist of a started broadcast.
class XBroadcastStream {
  final Uri playlist;
  final String? title;
  final XBroadcastState state;

  const XBroadcastStream({
    required this.playlist,
    required this.state,
    this.title,
  });

  bool get live => state == XBroadcastState.live;
}

import 'dart:isolate';

import 'news_error.dart';
import 'news_feed_parser.dart';
import 'news_http.dart';
import 'news_source.dart';

class NewsFeedFetch {
  final ParsedFeed? feed;
  final String? etag;
  final String? lastModified;
  final bool notModified;

  const NewsFeedFetch({
    this.feed,
    this.etag,
    this.lastModified,
    this.notModified = false,
  });
}

/// One conditional GET per source. Kept separate from persistence so a slow or
/// broken feed can fail alone without touching the other sources.
class NewsFeedService {
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxBytes = 8 * 1024 * 1024;

  static Future<NewsFeedFetch> fetch(NewsSource source) async {
    final uri = NewsHttp.parseUrl(source.feedUrl);
    final etag = source.etag;
    final lastModified = source.lastModified;
    final response = await NewsHttp.get(
      uri,
      accept:
          'application/rss+xml, application/atom+xml, application/xml;q=0.9, '
          'text/xml;q=0.8, */*;q=0.5',
      timeout: _timeout,
      maxBytes: _maxBytes,
      headers: {
        if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
        if (lastModified != null && lastModified.isNotEmpty)
          'If-Modified-Since': lastModified,
      },
    );
    if (response.statusCode == 304) {
      return const NewsFeedFetch(notModified: true);
    }

    final bytes = response.bodyBytes;
    final contentType = response.headers['content-type'];
    final shortId = source.shortId;
    final feedUrl = source.feedUrl;
    // Large feeds take tens of milliseconds to decode and parse.
    final feed = await Isolate.run(
      () => NewsFeedParser.parse(
        NewsHttp.decodeBody(bytes, contentType),
        sourceShortId: shortId,
        feedUrl: feedUrl,
      ),
    );
    return NewsFeedFetch(
      feed: feed,
      etag: response.headers['etag'],
      lastModified: response.headers['last-modified'],
    );
  }

  /// [shortId] must be the id the source will be saved under: article keys
  /// are derived from it.
  static Future<ParsedFeed> probe(
    String feedUrl, {
    required String shortId,
  }) async {
    final result = await fetch(
      NewsSource(
        shortId: shortId,
        title: '',
        feedUrl: feedUrl,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    final feed = result.feed;
    if (feed == null) throw const NewsException(NewsError.noEntries);
    return feed;
  }
}

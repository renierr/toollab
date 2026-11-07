import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

import 'news_feed_parser.dart';
import 'news_source.dart';

class NewsFeedException implements Exception {
  final String message;

  const NewsFeedException(this.message);

  @override
  String toString() => message;
}

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
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxBytes = 8 * 1024 * 1024;

  static Future<NewsFeedFetch> fetch(NewsSource source) async {
    final uri = Uri.tryParse(source.feedUrl);
    if (uri == null || !uri.hasScheme) {
      throw const NewsFeedException('Invalid feed URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const NewsFeedException('Feed URL must use http or https');
    }

    final headers = <String, String>{
      'User-Agent': _userAgent,
      'Accept':
          'application/rss+xml, application/atom+xml, application/xml;q=0.9, '
          'text/xml;q=0.8, */*;q=0.5',
      'Accept-Language': 'en-US,en;q=0.9,de;q=0.8',
      if (source.etag != null && source.etag!.isNotEmpty)
        'If-None-Match': source.etag!,
      if (source.lastModified != null && source.lastModified!.isNotEmpty)
        'If-Modified-Since': source.lastModified!,
    };

    final http.Response response;
    try {
      final client = await AppHttpClient.client;
      response = await client.get(uri, headers: headers).timeout(_timeout);
    } catch (e) {
      throw NewsFeedException('Could not reach feed: $e');
    }

    if (response.statusCode == 304) {
      return const NewsFeedFetch(notModified: true);
    }
    if (response.statusCode >= 400) {
      throw NewsFeedException('Feed answered ${response.statusCode}');
    }
    if (response.bodyBytes.length > _maxBytes) {
      throw const NewsFeedException('Feed is too large');
    }

    final body = _decodeBody(response);
    final feed = NewsFeedParser.parse(
      body,
      sourceShortId: source.shortId,
      feedUrl: source.feedUrl,
    );
    return NewsFeedFetch(
      feed: feed,
      etag: response.headers['etag'],
      lastModified: response.headers['last-modified'],
    );
  }

  static Future<ParsedFeed> probe(String feedUrl) async {
    final probeSource = NewsSource(
      shortId: 'probe',
      title: '',
      feedUrl: feedUrl,
      createdAt: 0,
      updatedAt: 0,
    );
    final result = await fetch(probeSource);
    final feed = result.feed;
    if (feed == null) throw const NewsFeedException('Feed has no entries');
    return feed;
  }

  static String _decodeBody(http.Response response) {
    final charset = RegExp(
      r'charset\s*=\s*"?([\w-]+)',
      caseSensitive: false,
    ).firstMatch(response.headers['content-type'] ?? '')?.group(1);
    final encoding = charset == null ? null : Encoding.getByName(charset);
    final body = encoding != null
        ? encoding.decode(response.bodyBytes)
        : utf8.decode(response.bodyBytes, allowMalformed: true);
    return body.startsWith('\uFEFF') ? body.substring(1) : body;
  }
}

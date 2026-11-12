import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import '../models/x_post.dart';
import '../models/x_user.dart';
import 'x_session.dart';
import 'x_timeline_parser.dart';
import 'x_web_config.dart';

enum XApiErrorKind { unauthorized, rateLimited, network, unsupported, server }

class XApiException implements Exception {
  final XApiErrorKind kind;
  final String? message;

  const XApiException(this.kind, [this.message]);

  @override
  String toString() =>
      'XApiException($kind${message == null ? '' : ': $message'})';
}

enum XSearchProduct { top, latest, media }

/// The private GraphQL API x.com's own web app talks to, authenticated with
/// the session cookies. Every response's fresh `ct0` is kept, and a rejected
/// query refreshes [XWebConfig] once before giving up.
class XApi {
  XSession _session;
  final void Function(XSession session)? onSessionChanged;

  XWebConfig? _config;
  Future<XWebConfig>? _configLoad;

  XApi(this._session, {this.onSessionChanged});

  /// The public token of the x.com web app itself, the same for every user.
  static const String _bearer =
      'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D'
      '1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA';
  static const Duration _timeout = Duration(seconds: 25);
  static final RegExp _ct0Pattern = RegExp(r'(?:^|[\s,;])ct0=([^;,\s]+)');

  XSession get session => _session;

  Future<XWebConfig> _ensureConfig({bool force = false}) async {
    final current = _config;
    if (!force && current != null && !current.isStale) return current;
    if (!force && current == null) {
      final cached = await XWebConfig.loadCached();
      if (cached != null && !cached.isStale) return _config = cached;
    }
    final pending = _configLoad;
    if (pending != null) return pending;
    final load = _fetchConfig();
    _configLoad = load;
    try {
      return _config = await load;
    } finally {
      _configLoad = null;
    }
  }

  Future<XWebConfig> _fetchConfig() async {
    try {
      return await XWebConfig.fetch(await AppHttpClient.client, _session);
    } on FormatException catch (e) {
      throw XApiException(XApiErrorKind.unsupported, '$e');
    } catch (e) {
      throw XApiException(XApiErrorKind.network, '$e');
    }
  }

  Future<void> refreshConfig() async {
    await XWebConfig.clearCache();
    _config = null;
    await _ensureConfig(force: true);
  }

  Map<String, String> _headers(
    XWebConfig? config,
    String method,
    String path, {
    String language = 'en',
  }) {
    final headers = {
      'Authorization': 'Bearer $_bearer',
      'X-Csrf-Token': _session.csrfToken,
      'Cookie': _session.cookieHeader,
      'X-Twitter-Auth-Type': 'OAuth2Session',
      'X-Twitter-Active-User': 'yes',
      'X-Twitter-Client-Language': language,
      'User-Agent': XWebConfig.userAgent,
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Origin': 'https://x.com',
      'Referer': 'https://x.com/home',
    };
    final transaction = config?.transaction;
    if (transaction != null) {
      headers['X-Client-Transaction-Id'] = transaction.generate(method, path);
    }
    return headers;
  }

  void _captureCsrf(http.Response res) {
    final cookies = res.headers['set-cookie'];
    if (cookies == null) return;
    final csrf = _ct0Pattern.firstMatch(cookies)?.group(1);
    if (csrf == null || csrf == _session.csrfToken) return;
    _session = _session.withCsrf(csrf);
    onSessionChanged?.call(_session);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers, {
    String? body,
  }) async {
    final client = await AppHttpClient.client;
    try {
      final future = method == 'POST'
          ? client.post(uri, headers: headers, body: body)
          : client.get(uri, headers: headers);
      final res = await future.timeout(_timeout);
      _captureCsrf(res);
      return res;
    } on TimeoutException {
      throw const XApiException(XApiErrorKind.network, 'timeout');
    } catch (e) {
      throw XApiException(XApiErrorKind.network, '$e');
    }
  }

  Future<Map<String, dynamic>> _graphql(
    String name,
    Map<String, Object?> variables, {
    bool post = false,
    Map<String, bool> fieldToggles = const {},
    Map<String, bool> featureOverrides = const {},
    String language = 'en',
    bool retried = false,
  }) async {
    final config = await _ensureConfig();
    final op = config.operations[name];
    if (op == null) {
      if (!retried && !config.isStale) {
        await _ensureConfig(force: true);
        return _graphql(
          name,
          variables,
          post: post,
          fieldToggles: fieldToggles,
          featureOverrides: featureOverrides,
          language: language,
          retried: true,
        );
      }
      throw XApiException(XApiErrorKind.unsupported, 'Unknown operation $name');
    }

    final path = '/i/api/graphql/${op.queryId}/${op.name}';
    final cleanVariables = {
      for (final e in variables.entries)
        if (e.value != null) e.key: e.value,
    };
    final toggles = {
      for (final name in op.fieldToggles) name: fieldToggles[name] ?? false,
    };
    final features = {
      ...config.featuresFor(op),
      for (final e in featureOverrides.entries)
        if (op.features.contains(e.key)) e.key: e.value,
    };

    final http.Response res;
    if (post) {
      res = await _send(
        'POST',
        Uri.https('x.com', path),
        _headers(config, 'POST', path, language: language),
        body: jsonEncode({
          'variables': cleanVariables,
          if (features.isNotEmpty) 'features': features,
          if (toggles.isNotEmpty) 'fieldToggles': toggles,
          'queryId': op.queryId,
        }),
      );
    } else {
      final uri = Uri.https('x.com', path, {
        'variables': jsonEncode(cleanVariables),
        if (features.isNotEmpty) 'features': jsonEncode(features),
        if (toggles.isNotEmpty) 'fieldToggles': jsonEncode(toggles),
      });
      res = await _send(
        'GET',
        uri,
        _headers(config, 'GET', path, language: language),
      );
    }

    switch (res.statusCode) {
      case 200:
        final json = _decode(res.body);
        if (json['data'] == null && json['errors'] != null) {
          throw XApiException(XApiErrorKind.server, _errorMessage(json));
        }
        return json;
      case 401:
        throw const XApiException(XApiErrorKind.unauthorized);
      case 403:
        if (!retried && res.body.contains('353')) {
          return _graphql(
            name,
            variables,
            post: post,
            fieldToggles: fieldToggles,
            featureOverrides: featureOverrides,
            language: language,
            retried: true,
          );
        }
        throw XApiException(XApiErrorKind.unauthorized, _bodyMessage(res.body));
      case 429:
        throw const XApiException(XApiErrorKind.rateLimited);
      case 400:
      case 404:
      case 422:
        if (!retried) {
          debugLog(
            '[XApi] $name answered ${res.statusCode}; refreshing config',
          );
          await _ensureConfig(force: true);
          return _graphql(
            name,
            variables,
            post: post,
            fieldToggles: fieldToggles,
            featureOverrides: featureOverrides,
            language: language,
            retried: true,
          );
        }
        throw XApiException(XApiErrorKind.unsupported, _bodyMessage(res.body));
      default:
        throw XApiException(
          XApiErrorKind.server,
          'HTTP ${res.statusCode}: ${_bodyMessage(res.body)}',
        );
    }
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw XApiException(XApiErrorKind.server, 'Invalid JSON: $e');
    }
  }

  static String? _errorMessage(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      return (errors.first as Map)['message'] as String?;
    }
    return null;
  }

  static String _bodyMessage(String body) {
    try {
      return _errorMessage(jsonDecode(body) as Map<String, dynamic>) ?? body;
    } catch (_) {
      return body.length > 200 ? body.substring(0, 200) : body;
    }
  }

  Future<String?> viewerScreenName() async {
    const path = '/i/api/1.1/account/settings.json';
    final config = await _ensureConfig();
    final res = await _send(
      'GET',
      Uri.https('x.com', path),
      _headers(config, 'GET', path),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const XApiException(XApiErrorKind.unauthorized);
    }
    if (res.statusCode != 200) return null;
    return _decode(res.body)['screen_name'] as String?;
  }

  /// [seenPostIds] tells X which posts were already on screen, as the web
  /// app does, so the ranking stops serving them again. Like x.com, a request
  /// carrying them is a POST, so their number is not bound by URL length.
  Future<XTimelinePage> homeTimeline({
    required bool following,
    String? cursor,
    List<String> seenPostIds = const [],
    int count = 20,
  }) async {
    final json =
        await _graphql(following ? 'HomeLatestTimeline' : 'HomeTimeline', {
          'count': count,
          'cursor': cursor,
          'includePromotedContent': false,
          'latestControlAvailable': true,
          'requestContext': cursor == null ? 'launch' : null,
          'withCommunity': true,
          'seenTweetIds': seenPostIds.isEmpty ? null : seenPostIds,
        }, post: seenPostIds.isNotEmpty);
    return XTimelineParser.parse(json);
  }

  Future<XTimelinePage> postDetail(String postId, {String? cursor}) async {
    final json = await _graphql(
      'TweetDetail',
      {
        'focalTweetId': postId,
        'cursor': cursor,
        'referrer': 'tweet',
        'with_rux_injections': false,
        'rankingMode': 'Relevance',
        'includePromotedContent': false,
        'withCommunity': true,
        'withQuickPromoteEligibilityTweetFields': false,
        'withBirdwatchNotes': true,
        'withVoice': true,
      },
      fieldToggles: const {'withArticleRichContentState': true},
    );
    return XTimelineParser.parse(json);
  }

  Future<XUser?> user(String screenName) async {
    final json = await _graphql('UserByScreenName', {
      'screen_name': screenName,
      'withSafetyModeUserFields': true,
    });
    final data = json['data'];
    if (data is! Map) return null;
    final user = data['user'];
    return XTimelineParser.parseUser(user is Map ? user['result'] : null);
  }

  Future<XTimelinePage> userPosts(
    String userId, {
    bool mediaOnly = false,
    String? cursor,
  }) async {
    final json = await _graphql(mediaOnly ? 'UserMedia' : 'UserTweets', {
      'userId': userId,
      'count': 20,
      'cursor': cursor,
      'includePromotedContent': false,
      'withQuickPromoteEligibilityTweetFields': false,
      'withVoice': true,
      'withClientEventToken': false,
      'withBirdwatchNotes': false,
    });
    return XTimelineParser.parse(json);
  }

  Future<XTimelinePage> search(
    String query, {
    XSearchProduct product = XSearchProduct.top,
    String? cursor,
  }) async {
    final json = await _graphql('SearchTimeline', {
      'rawQuery': query,
      'count': 20,
      'cursor': cursor,
      'querySource': 'typed_query',
      'product': switch (product) {
        XSearchProduct.top => 'Top',
        XSearchProduct.latest => 'Latest',
        XSearchProduct.media => 'Media',
      },
    });
    return XTimelineParser.parse(json);
  }

  Future<XTimelinePage> bookmarks({String? cursor}) async {
    final json = await _graphql('Bookmarks', {
      'count': 20,
      'cursor': cursor,
      'includePromotedContent': false,
    });
    return XTimelineParser.parse(json);
  }

  Future<void> setLiked(String postId, bool liked) => _graphql(
    liked ? 'FavoriteTweet' : 'UnfavoriteTweet',
    {'tweet_id': postId},
    post: true,
  );

  Future<void> setReposted(String postId, bool reposted) => _graphql(
    reposted ? 'CreateRetweet' : 'DeleteRetweet',
    reposted
        ? {'tweet_id': postId, 'dark_request': false}
        : {'source_tweet_id': postId, 'dark_request': false},
    post: true,
  );

  Future<void> setBookmarked(String postId, bool bookmarked) => _graphql(
    bookmarked ? 'CreateBookmark' : 'DeleteBookmark',
    {'tweet_id': postId},
    post: true,
  );

  /// Translates into [language] the way x.com does: the Grok translation X
  /// attaches to a post fetched in the reader's client language, else the
  /// older `translateTweet` strato column. Null when X has none.
  Future<XTranslation?> translatePost(XPost post, String language) async {
    final hasMedia = post.media.isNotEmpty;
    try {
      final json = await _graphql(
        'TweetResultByRestId',
        {
          'tweetId': post.id,
          'includePromotedContent': false,
          'withBirdwatchNotes': false,
          'withVoice': true,
          'withCommunity': true,
        },
        featureOverrides: const {
          'responsive_web_grok_show_grok_translated_post': true,
          'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
        },
        language: language,
      );
      final grok = XTimelineParser.parseGrokTranslation(
        json,
        hasMedia: hasMedia,
      );
      if (grok != null) return grok;
    } on XApiException catch (e) {
      if (e.kind == XApiErrorKind.unauthorized ||
          e.kind == XApiErrorKind.rateLimited) {
        rethrow;
      }
      debugLog('[XApi] Grok translation of ${post.id} failed: $e');
    }
    return _stratoTranslation(post.id, language, hasMedia: hasMedia);
  }

  Future<XTranslation?> _stratoTranslation(
    String postId,
    String language, {
    required bool hasMedia,
  }) async {
    final path =
        '/i/api/1.1/strato/column/None/tweetId=$postId,destinationLanguage=None,'
        'translationSource=Some(X),feature=None,timeout=None,onlyCached=None'
        '/translation/service/translateTweet';
    final config = await _ensureConfig();
    final res = await _send(
      'GET',
      Uri.https('x.com', path),
      _headers(config, 'GET', path, language: language),
    );
    switch (res.statusCode) {
      case 200:
        return XTimelineParser.parseTranslation(
          _decode(res.body),
          hasMedia: hasMedia,
        );
      case 401:
        throw const XApiException(XApiErrorKind.unauthorized);
      case 429:
        throw const XApiException(XApiErrorKind.rateLimited);
      default:
        // A 403 here is a refused translation, not an expired session.
        throw XApiException(
          XApiErrorKind.server,
          'HTTP ${res.statusCode}: ${_bodyMessage(res.body)}',
        );
    }
  }
}

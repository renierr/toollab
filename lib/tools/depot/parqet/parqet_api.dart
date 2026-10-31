import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_holding.dart';
import '../models/depot_period.dart';
import '../models/depot_portfolio.dart';
import '../models/depot_summary.dart';
import '../models/depot_transaction.dart';
import '../models/parqet_json.dart';
import 'parqet_auth.dart';
import 'parqet_exception.dart';

class ParqetPerformance {
  final DepotSummary summary;
  final List<DepotHolding> holdings;
  final List<DepotHoldingPerformance> holdingPerformance;
  final List<DepotChartPoint> chart;

  /// Parqet's activity count per holding id; holdings without one are absent.
  final Map<String, int> activityCounts;

  const ParqetPerformance({
    required this.summary,
    required this.holdings,
    required this.holdingPerformance,
    required this.chart,
    this.activityCounts = const {},
  });
}

class ParqetActivities {
  final List<DepotTransaction> items;

  /// False when paging stopped at the sync watermark, so older stored
  /// activities are still the only copy and must be kept.
  final bool complete;

  const ParqetActivities({required this.items, required this.complete});
}

/// Read-only client for the Parqet Connect REST API.
class ParqetApi {
  final String clientId;

  const ParqetApi({required this.clientId});

  static final Uri _baseUri = Uri.parse('https://connect.parqet.com');
  static const _timeout = Duration(seconds: 30);
  static const _activityPageSize = 500;
  static const _createBatchSize = 100;
  static const _snippetLength = 500;
  static const _maxRetryAfter = Duration(seconds: 120);

  Future<List<DepotPortfolio>> portfolios() async {
    final json = await _send('GET', '/portfolios');
    return [
      for (final item in json['items'] as List? ?? const [])
        DepotPortfolio.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Performance of [portfolioIds] combined over `key.period`, tagged with
  /// `key.scope`. Holdings are only attributable when a single portfolio is
  /// requested, so they carry the scope as their portfolio id.
  Future<ParqetPerformance> performance({
    required DepotPeriodKey key,
    required List<String> portfolioIds,
    required String currency,
  }) async {
    final json = await _send(
      'POST',
      '/performance',
      body: {
        'portfolioIds': portfolioIds,
        'currency': currency,
        'interval': _interval(key.period),
      },
    );
    final syncedAt = DateTime.now();
    final holdings = [
      for (final item in json['holdings'] as List? ?? const [])
        item as Map<String, dynamic>,
    ];
    return ParqetPerformance(
      summary: DepotSummary.fromJson(
        key: key,
        currency: currency,
        performance: json['performance'] as Map<String, dynamic>? ?? const {},
        syncedAt: syncedAt,
      ),
      holdings: [
        for (final item in holdings) DepotHolding.fromJson(key.scope, item),
      ],
      holdingPerformance: [
        for (final item in holdings)
          DepotHoldingPerformance.fromJson(key.scope, key.period, item),
      ],
      chart: [
        for (final item in json['charts'] as List? ?? const [])
          ?DepotChartPoint.fromJson(item as Map<String, dynamic>),
      ],
      activityCounts: {
        for (final item in holdings)
          if (item['activityCount'] case final num count)
            item['id'] as String: count.toInt(),
      },
    );
  }

  /// Portfolio ids this login may create activities in; null when Parqet
  /// lists no portfolio permission at all, so nothing can be concluded.
  Future<Set<String>?> writablePortfolioIds() async {
    final json = await _send('GET', '/user');
    final writable = <String>{};
    var listed = false;
    for (final item in json['permissions'] as List? ?? const []) {
      if (item case {
        'action': final String action,
        'resourceType': 'portfolio',
        'resourceId': final String id,
      }) {
        listed = true;
        if (action == 'write') writable.add(id);
      }
    }
    return listed ? writable : null;
  }

  /// Parqet's relative `1d` starts at the close before yesterday, so today is
  /// requested as an absolute range from midnight.
  static Map<String, String> _interval(DepotPeriod period) {
    if (period != DepotPeriod.today) {
      return {'type': 'relative', 'value': period.wire};
    }
    final now = DateTime.now();
    final start = DateTime.utc(now.year, now.month, now.day);
    return {'type': 'absolute', 'start': start.toIso8601String()};
  }

  /// Activities of [portfolioId], newest page first. With [since] the walk
  /// stops once a page runs past it, so a routine sync only downloads what
  /// was added. That needs the feed to be newest first; if it is not, every
  /// page is read and [ParqetActivities.complete] stays true. [holdingId]
  /// limits the read to one holding.
  Future<ParqetActivities> activities(
    String portfolioId, {
    DateTime? since,
    String? holdingId,
  }) async {
    final result = <DepotTransaction>[];
    String? cursor;
    var complete = true;
    do {
      final json = await _send(
        'GET',
        '/portfolios/$portfolioId/activities',
        query: {
          'limit': '$_activityPageSize',
          'cursor': ?cursor,
          'holdingId': ?holdingId,
        },
      );
      final page = <DepotTransaction>[];
      for (final item in json['activities'] as List? ?? const []) {
        final activity = DepotTransaction.fromJson(
          portfolioId,
          item as Map<String, dynamic>,
        );
        if (activity != null) page.add(activity);
      }
      result.addAll(page);
      if (since != null && _isBehind(page, since)) {
        complete = false;
        break;
      }
      final next = json['cursor'] as String?;
      cursor = next == null || next.isEmpty || next == cursor ? null : next;
    } while (cursor != null);
    return ParqetActivities(items: result, complete: complete);
  }

  /// A page that runs newest first and whose oldest entry predates [since]
  /// means everything further back is already stored.
  static bool _isBehind(List<DepotTransaction> page, DateTime since) {
    if (page.length < 2) return false;
    if (!page.first.datetime.isAfter(page.last.datetime)) return false;
    return page.last.datetime.isBefore(since);
  }

  /// Creates [activities] in [portfolioId] and returns Parqet's reason for
  /// every one it rejected, keyed by its index in [activities].
  Future<Map<int, String>> createActivities(
    String portfolioId,
    List<Map<String, Object?>> activities,
  ) async {
    final rejected = <int, String>{};
    for (var start = 0; start < activities.length; start += _createBatchSize) {
      final batch = activities.skip(start).take(_createBatchSize).toList();
      final json = await _send(
        'POST',
        '/portfolios/$portfolioId/activities',
        body: {'activities': batch},
      );
      for (final item in json['notCreatedActivities'] as List? ?? const []) {
        final error = ParqetJson.object((item as Map)['error']);
        final index = (error['originalIndex'] as num?)?.toInt();
        if (index == null) continue;
        rejected[start + index] =
            error['message'] as String? ?? error['code'] as String? ?? '';
      }
    }
    return rejected;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = _baseUri.replace(
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    var token = await ParqetAuth.accessToken(clientId);
    var res = await _request(method, uri, token, body);
    // A token can be rejected before its local expiry, e.g. when another
    // isolate already rotated it; one refresh is worth a retry.
    if (res.statusCode == 401) {
      token = await ParqetAuth.accessTokenReplacing(clientId, token);
      res = await _request(method, uri, token, body);
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      _logHttpFailure(method, path, res);
    }

    switch (res.statusCode) {
      case 200 || 201:
        break;
      case 401:
        throw ParqetException.detailed(
          ParqetErrorKind.unauthorized,
          '$method $path: HTTP 401 ${_snippet(res.body)}',
          statusCode: 401,
        );
      case 403:
        throw ParqetException.detailed(
          ParqetErrorKind.scopeNotAllowed,
          '$method $path: HTTP 403 ${_snippet(res.body)}',
          statusCode: 403,
        );
      case 429:
        throw ParqetException.detailed(
          ParqetErrorKind.rateLimited,
          '$method $path: HTTP 429 ${_snippet(res.body)}',
          retryAfter: _retryAfter(res.headers),
          statusCode: 429,
        );
      default:
        throw ParqetException.detailed(
          ParqetErrorKind.server,
          '$method $path: HTTP ${res.statusCode} ${_snippet(res.body)}',
          statusCode: res.statusCode,
        );
    }

    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      errorLog(
        '[ParqetApi] $method $path -> invalid JSON: $e '
        'body=${_snippet(res.body)}',
      );
      throw ParqetException(ParqetErrorKind.invalidResponse, '$path: $e');
    }
  }

  static void _logHttpFailure(String method, String path, http.Response res) {
    final retryAfter = _retryAfter(res.headers);
    final rateLimit = [
      for (final name in _rateLimitHeaders)
        if (res.headers[name] case final value?) '$name=$value',
    ];
    errorLog(
      '[ParqetApi] $method $path -> HTTP ${res.statusCode}'
      '${retryAfter == null ? '' : ' retry-after=${retryAfter.inSeconds}s'}'
      '${rateLimit.isEmpty ? '' : ' ${rateLimit.join(' ')}'}'
      ' body=${_snippet(res.body)}',
    );
  }

  static const _rateLimitHeaders = [
    'x-ratelimit-limit',
    'x-ratelimit-remaining',
    'x-ratelimit-reset',
  ];

  /// `Retry-After` is either seconds or an HTTP date; an absurd wait is capped.
  static Duration? _retryAfter(Map<String, String> headers) {
    final raw = headers['retry-after']?.trim();
    if (raw == null || raw.isEmpty) return null;
    Duration? wait;
    if (int.tryParse(raw) case final seconds?) {
      wait = Duration(seconds: seconds);
    } else {
      try {
        wait = HttpDate.parse(raw).difference(DateTime.now().toUtc());
      } on FormatException {
        return null;
      }
    }
    if (wait.isNegative) return Duration.zero;
    return wait > _maxRetryAfter ? _maxRetryAfter : wait;
  }

  static String _snippet(String body) => body.length <= _snippetLength
      ? body
      : '${body.substring(0, _snippetLength)}…';

  Future<http.Response> _request(
    String method,
    Uri uri,
    String token,
    Object? body,
  ) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final client = await AppHttpClient.client;
    try {
      return await switch (method) {
        'POST' => client.post(uri, headers: headers, body: jsonEncode(body)),
        _ => client.get(uri, headers: headers),
      }.timeout(_timeout);
    } catch (e) {
      errorLog('[ParqetApi] $method ${uri.path} -> network failure: $e');
      throw ParqetException(ParqetErrorKind.network, '$method ${uri.path}: $e');
    }
  }
}

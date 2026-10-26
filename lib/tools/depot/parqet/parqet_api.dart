import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_holding.dart';
import '../models/depot_period.dart';
import '../models/depot_portfolio.dart';
import '../models/depot_summary.dart';
import '../models/depot_transaction.dart';
import 'parqet_auth.dart';
import 'parqet_exception.dart';

class ParqetPerformance {
  final DepotSummary summary;
  final List<DepotHolding> holdings;
  final List<DepotHoldingPerformance> holdingPerformance;
  final List<DepotChartPoint> chart;

  const ParqetPerformance({
    required this.summary,
    required this.holdings,
    required this.holdingPerformance,
    required this.chart,
  });
}

/// Read-only client for the Parqet Connect REST API.
class ParqetApi {
  final String clientId;

  const ParqetApi({required this.clientId});

  static final Uri _baseUri = Uri.parse('https://connect.parqet.com');
  static const _timeout = Duration(seconds: 30);
  static const _activityPageSize = 500;

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
        'interval': {'type': 'relative', 'value': key.period.wire},
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
    );
  }

  Future<List<DepotTransaction>> activities(String portfolioId) async {
    final result = <DepotTransaction>[];
    String? cursor;
    do {
      final json = await _send(
        'GET',
        '/portfolios/$portfolioId/activities',
        query: {'limit': '$_activityPageSize', 'cursor': ?cursor},
      );
      for (final item in json['activities'] as List? ?? const []) {
        final activity = DepotTransaction.fromJson(
          portfolioId,
          item as Map<String, dynamic>,
        );
        if (activity != null) result.add(activity);
      }
      final next = json['cursor'] as String?;
      cursor = next == null || next.isEmpty || next == cursor ? null : next;
    } while (cursor != null);
    return result;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final token = await ParqetAuth.accessToken(clientId);
    final uri = _baseUri.replace(
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final client = await AppHttpClient.client;
    final http.Response res;
    try {
      res = await switch (method) {
        'POST' => client.post(uri, headers: headers, body: jsonEncode(body)),
        _ => client.get(uri, headers: headers),
      }.timeout(_timeout);
    } catch (e) {
      throw ParqetException(ParqetErrorKind.network, '$e');
    }

    switch (res.statusCode) {
      case 200 || 201:
        break;
      case 401 || 403:
        throw ParqetException(ParqetErrorKind.unauthorized, res.body);
      case 429:
        throw ParqetException(ParqetErrorKind.rateLimited, res.body);
      default:
        throw ParqetException(
          ParqetErrorKind.server,
          '$method $path: HTTP ${res.statusCode} ${res.body}',
        );
    }

    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw ParqetException(ParqetErrorKind.invalidResponse, '$path: $e');
    }
  }
}

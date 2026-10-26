import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_dividend.dart';

class YahooFinanceException implements Exception {
  final String message;

  const YahooFinanceException(this.message);

  @override
  String toString() => 'YahooFinanceException: $message';
}

typedef YahooDividends = ({String currency, List<DepotDividendEvent> events});
typedef YahooNextDividend = ({DateTime? exDate, DateTime? payDate});

/// Unofficial, keyless Yahoo Finance endpoints. They may change without
/// notice, so every caller treats a failure as "no data".
class YahooFinanceApi {
  YahooFinanceApi._();

  static final Uri _base = Uri.parse('https://query2.finance.yahoo.com');
  static const _timeout = Duration(seconds: 20);

  // Yahoo rejects requests without a browser-like user agent.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/130.0 Safari/537.36',
    'Accept': 'application/json',
  };

  /// The first listing Yahoo knows for [query], an ISIN or a ticker.
  static Future<String?> symbolFor(String query) async {
    final json = await _getJson('/v1/finance/search', {
      'q': query,
      'quotesCount': '5',
      'newsCount': '0',
    });
    for (final quote in json['quotes'] as List? ?? const []) {
      final symbol = (quote as Map)['symbol'];
      if (symbol is String && symbol.isNotEmpty) return symbol;
    }
    return null;
  }

  static Future<YahooDividends> dividends(String symbol) async {
    final json = await _getJson(
      '/v8/finance/chart/${Uri.encodeComponent(symbol)}',
      {'range': '10y', 'interval': '1mo', 'events': 'div'},
    );
    final result = _chartResult(json);
    var currency = (result['meta'] as Map?)?['currency'] as String? ?? '';
    // London quotes in pence; the portfolio thinks in pounds.
    final divisor = currency == 'GBp' || currency == 'GBX' ? 100.0 : 1.0;
    if (divisor != 1) currency = 'GBP';
    final raw = (result['events'] as Map?)?['dividends'] as Map? ?? const {};
    final events = <DepotDividendEvent>[
      for (final item in raw.values)
        if (item is Map && item['date'] is num && item['amount'] is num)
          DepotDividendEvent(
            exDate: _date(item['date'] as num),
            amount: (item['amount'] as num).toDouble() / divisor,
          ),
    ]..sort((a, b) => a.exDate.compareTo(b.exDate));
    return (currency: currency, events: events);
  }

  /// Units of [to] per unit of [from].
  static Future<double> fxRate(String from, String to) async {
    if (from == to) return 1;
    final json = await _getJson('/v8/finance/chart/$from$to=X', {
      'range': '1d',
      'interval': '1d',
    });
    final meta = _chartResult(json)['meta'] as Map?;
    final rate = meta?['regularMarketPrice'];
    if (rate is! num || rate <= 0) {
      throw YahooFinanceException('No rate for $from/$to');
    }
    return rate.toDouble();
  }

  /// Cookie and crumb that the quote summary endpoint demands. Null when
  /// Yahoo refuses, which only costs the announced dates.
  static Future<YahooSession?> session() async {
    try {
      final client = await AppHttpClient.client;
      final cookieRes = await client
          .get(Uri.parse('https://fc.yahoo.com'), headers: _headers)
          .timeout(_timeout);
      final cookie = _cookieHeader(cookieRes.headers['set-cookie']);
      if (cookie == null) return null;
      final crumbRes = await client
          .get(
            _base.replace(path: '/v1/test/getcrumb'),
            headers: {..._headers, 'Cookie': cookie},
          )
          .timeout(_timeout);
      final crumb = crumbRes.body.trim();
      if (crumbRes.statusCode != 200 || crumb.isEmpty || crumb.contains('<')) {
        return null;
      }
      return YahooSession(cookie: cookie, crumb: crumb);
    } catch (_) {
      return null;
    }
  }

  static Future<YahooNextDividend> nextDividend(
    String symbol,
    YahooSession session,
  ) async {
    final json = await _getJson(
      '/v10/finance/quoteSummary/${Uri.encodeComponent(symbol)}',
      {'modules': 'calendarEvents', 'crumb': session.crumb},
      cookie: session.cookie,
    );
    final results = (json['quoteSummary'] as Map?)?['result'] as List?;
    final calendar = results == null || results.isEmpty
        ? null
        : (results.first as Map)['calendarEvents'] as Map?;
    DateTime? raw(Object? field) {
      final value = field is Map ? field['raw'] : null;
      return value is num ? _date(value) : null;
    }

    return (
      exDate: raw(calendar?['exDividendDate']),
      payDate: raw(calendar?['dividendDate']),
    );
  }

  static Map _chartResult(Map<String, dynamic> json) {
    final results = (json['chart'] as Map?)?['result'] as List?;
    if (results == null || results.isEmpty) {
      throw const YahooFinanceException('Empty chart result');
    }
    return results.first as Map;
  }

  /// Yahoo stamps dates at market open; only the calendar day matters.
  static DateTime _date(num seconds) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    );
    return DateTime(utc.year, utc.month, utc.day);
  }

  static String? _cookieHeader(String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return null;
    // Several Set-Cookie headers arrive joined by commas, which also appear
    // inside expiry dates, so split only where a new name=value starts.
    final cookies = setCookie
        .split(RegExp(r',(?=\s*[^;,=\s]+=)'))
        .map((c) => c.split(';').first.trim())
        .where((c) => c.contains('='))
        .toList();
    return cookies.isEmpty ? null : cookies.join('; ');
  }

  static Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query, {
    String? cookie,
  }) async {
    final client = await AppHttpClient.client;
    final http.Response res;
    try {
      res = await client
          .get(
            _base.replace(path: path, queryParameters: query),
            headers: {..._headers, 'Cookie': ?cookie},
          )
          .timeout(_timeout);
    } catch (e) {
      throw YahooFinanceException('$path: $e');
    }
    if (res.statusCode != 200) {
      throw YahooFinanceException('$path: HTTP ${res.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw YahooFinanceException('$path: $e');
    }
  }
}

class YahooSession {
  final String cookie;
  final String crumb;

  const YahooSession({required this.cookie, required this.crumb});
}

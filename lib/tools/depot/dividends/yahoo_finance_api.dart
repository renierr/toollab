import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_dividend.dart';
import '../models/depot_wishlist.dart';
import '../parqet/parqet_asset_lookup.dart';
import '../parsing/security_parser.dart';

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

  /// Securities matching [query], limited to the kinds a wishlist follows.
  static Future<List<DepotWishlistSearchResult>> searchWishlist(
    String query,
  ) async {
    final isin = query.trim().toUpperCase();
    final matchingSymbols = SecurityParser.isValidIsin(isin)
        ? const ParqetAssetLookup()
              .symbolsForIsin(isin)
              .catchError((_) => <String>{})
        : Future.value(<String>{});
    final json = await _getJson('/v1/finance/search', {
      'q': query,
      'quotesCount': '20',
      'newsCount': '0',
    });
    final isinSymbols = await matchingSymbols;
    final results = <DepotWishlistSearchResult>[];
    for (final item in json['quotes'] as List? ?? const []) {
      if (item is! Map) continue;
      final symbol = item['symbol'];
      final quoteType = item['quoteType'];
      if (symbol is! String ||
          symbol.isEmpty ||
          quoteType is! String ||
          !wishlistQuoteTypes.contains(quoteType.toUpperCase())) {
        continue;
      }
      results.add(
        DepotWishlistSearchResult(
          symbol: symbol,
          name:
              (item['longname'] as String?) ??
              (item['shortname'] as String?) ??
              symbol,
          quoteType: quoteType,
          exchange:
              (item['exchDisp'] as String?) ??
              (item['exchange'] as String?) ??
              '',
          isin: isinSymbols.contains(symbol.toUpperCase()) ? isin : null,
        ),
      );
    }
    return results;
  }

  /// One year of daily closes plus the latest quote of [symbol].
  static Future<DepotWishlistQuote> wishlistQuote(String symbol) async {
    final json = await _getJson(
      '/v8/finance/chart/${Uri.encodeComponent(symbol)}',
      {'range': '1y', 'interval': '1d'},
    );
    return parseWishlistQuote(json, symbol);
  }

  @visibleForTesting
  static DepotWishlistQuote parseWishlistQuote(
    Map<String, dynamic> json,
    String symbol,
  ) {
    final result = _chartResult(json);
    final meta = result['meta'] as Map? ?? const {};
    var currency = meta['currency'] as String? ?? '';
    // London quotes in pence; the rest of the app thinks in pounds.
    final divisor = currency == 'GBp' || currency == 'GBX' ? 100.0 : 1.0;
    if (divisor != 1) currency = 'GBP';

    double? value(Object? raw) => raw is num ? raw.toDouble() / divisor : null;
    final timestamps = result['timestamp'] as List? ?? const [];
    final rawQuotes = (result['indicators'] as Map?)?['quote'] as List?;
    final quote = rawQuotes == null || rawQuotes.isEmpty
        ? null
        : rawQuotes.first;
    final closes = quote is Map
        ? quote['close'] as List? ?? const []
        : const [];
    final points = <DepotWishlistPoint>[];
    for (var i = 0; i < timestamps.length && i < closes.length; i++) {
      final close = value(closes[i]);
      final seconds = timestamps[i];
      if (close == null || seconds is! num) continue;
      points.add(
        DepotWishlistPoint(
          date: DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round()),
          close: close,
        ),
      );
    }
    if (points.isEmpty) {
      throw YahooFinanceException('No chart points for $symbol');
    }
    final price = value(meta['regularMarketPrice']) ?? points.last.close;
    final previousClose =
        value(meta['previousClose']) ??
        (points.length > 1 ? points[points.length - 2].close : price);
    final quoteTime = meta['regularMarketTime'];
    return DepotWishlistQuote(
      price: price,
      previousClose: previousClose,
      currency: currency,
      exchange:
          (meta['fullExchangeName'] as String?) ??
          (meta['exchangeName'] as String?) ??
          '',
      points: points,
      dayHigh: value(meta['regularMarketDayHigh']),
      dayLow: value(meta['regularMarketDayLow']),
      yearHigh: value(meta['fiftyTwoWeekHigh']),
      yearLow: value(meta['fiftyTwoWeekLow']),
      quoteAt: quoteTime is num
          ? DateTime.fromMillisecondsSinceEpoch((quoteTime * 1000).round())
          : null,
      quotedDayChangePercent: meta['regularMarketChangePercent'] is num
          ? (meta['regularMarketChangePercent'] as num).toDouble()
          : null,
    );
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

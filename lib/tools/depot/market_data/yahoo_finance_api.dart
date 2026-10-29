import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_asset_profile.dart';
import '../models/depot_dividend.dart';
import '../models/market_quote.dart';
import 'nasdaq_profile_api.dart';

class YahooFinanceException implements Exception {
  final String message;

  const YahooFinanceException(this.message);

  @override
  String toString() => 'YahooFinanceException: $message';
}

typedef YahooDividends = ({String currency, List<DepotDividendEvent> events});
typedef YahooNextDividend = ({DateTime? exDate, DateTime? payDate});

/// A profile plus the fund constituents it was derived from.
typedef YahooAssetProfile = ({
  DepotAssetProfile profile,
  List<({String symbol, double weight})> topHoldings,
});

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

  static Future<List<MarketSearchResult>> searchListings(
    String query, {
    int limit = 20,
  }) async {
    final json = await _getJson('/v1/finance/search', {
      'q': query,
      'quotesCount': '$limit',
      'newsCount': '0',
    });
    final results = <MarketSearchResult>[];
    for (final item in json['quotes'] as List? ?? const []) {
      if (item is! Map) continue;
      final symbol = item['symbol'];
      final quoteType = item['quoteType'];
      if (symbol is! String || symbol.isEmpty || quoteType is! String) {
        continue;
      }
      results.add(
        MarketSearchResult(
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
        ),
      );
    }
    return results;
  }

  static Future<MarketQuote> intradayQuote(String symbol, {DateTime? now}) {
    final end = (now ?? DateTime.now()).toUtc();
    return chartQuote(
      symbol,
      from: end.subtract(const Duration(hours: 24)),
      to: end,
      interval: '5m',
      includePrePost: true,
    );
  }

  static Future<MarketQuote> yearDailyQuote(String symbol) =>
      chartQuote(symbol, range: '1y', interval: '1d');

  static Future<MarketQuote> chartQuote(
    String symbol, {
    String? range,
    DateTime? from,
    DateTime? to,
    required String interval,
    bool includePrePost = false,
  }) async {
    if ((range != null && (from != null || to != null)) ||
        (range == null && (from == null || to == null)) ||
        (from != null && to != null && !from.isBefore(to))) {
      throw ArgumentError('Provide a range or both from and to');
    }
    final json =
        await _getJson('/v8/finance/chart/${Uri.encodeComponent(symbol)}', {
          'range': ?range,
          if (from != null) 'period1': '${from.millisecondsSinceEpoch ~/ 1000}',
          if (to != null) 'period2': '${to.millisecondsSinceEpoch ~/ 1000}',
          'interval': interval,
          if (includePrePost) 'includePrePost': 'true',
        });
    return parseChartQuote(
      json,
      symbol,
      dailyCloses: interval == '1d',
      from: from,
      to: to,
    );
  }

  @visibleForTesting
  static MarketQuote parseChartQuote(
    Map<String, dynamic> json,
    String symbol, {
    bool dailyCloses = true,
    DateTime? from,
    DateTime? to,
  }) {
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
    final points = <MarketPricePoint>[];
    for (var i = 0; i < timestamps.length && i < closes.length; i++) {
      final close = value(closes[i]);
      final seconds = timestamps[i];
      if (close == null || seconds is! num) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
      );
      if ((from != null && date.isBefore(from)) ||
          (to != null && date.isAfter(to))) {
        continue;
      }
      points.add(MarketPricePoint(date: date, close: close));
    }
    // fulldayPrice includes pre- and post-market trades, so a US listing
    // does not freeze at the last close while Wall Street is shut.
    final fulldayPrice = value(meta['fulldayPrice']);
    final price =
        fulldayPrice ??
        value(meta['regularMarketPrice']) ??
        (points.isEmpty ? null : points.last.close);
    if (price == null) {
      throw YahooFinanceException('No chart points for $symbol');
    }
    final previousClose =
        value(meta['previousClose']) ??
        value(meta['chartPreviousClose']) ??
        (dailyCloses && points.length > 1
            ? points[points.length - 2].close
            : 0);
    final regularTime = meta['regularMarketTime'];
    var quoteAt = regularTime is num
        ? DateTime.fromMillisecondsSinceEpoch((regularTime * 1000).round())
        : null;
    if (fulldayPrice != null &&
        points.isNotEmpty &&
        (quoteAt == null || points.last.date.isAfter(quoteAt))) {
      quoteAt = points.last.date;
    }
    final changePercent = fulldayPrice != null
        ? meta['fulldayChangePercent']
        : meta['regularMarketChangePercent'];
    return MarketQuote(
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
      quoteAt: quoteAt,
      quotedDayChangePercent: changePercent is num
          ? changePercent.toDouble()
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

  /// Sector, industry and country for [query], a ticker or an ISIN. The search
  /// endpoint works keyless; the quote summary adds the country and a fund's
  /// sector weights, but needs a session.
  static Future<YahooAssetProfile?> assetProfile(
    String query, {
    YahooSession? session,
  }) async {
    String? sector;
    String? industry;
    String? country;
    String? symbol;
    String? quoteType;
    var sectorShares = const <String, double>{};
    var topHoldings = const <({String symbol, double weight})>[];

    try {
      final json = await _getJson('/v1/finance/search', {
        'q': query,
        'quotesCount': '10',
        'newsCount': '0',
      });
      final match = _firstQuote(json, query);
      symbol = match?['symbol'] as String?;
      quoteType = match?['quoteType'] as String?;
      sector = match?['sector'] as String?;
      industry = match?['industry'] as String?;
    } catch (e) {
      debugLog('[YahooFinanceApi] Search profile failed for $query: $e');
    }

    if (session != null && (symbol ?? query).isNotEmpty) {
      try {
        final json = await _getJson(
          '/v10/finance/quoteSummary/${Uri.encodeComponent(symbol ?? query)}',
          {'modules': 'assetProfile,topHoldings', 'crumb': session.crumb},
          cookie: session.cookie,
        );
        final results = (json['quoteSummary'] as Map?)?['result'] as List?;
        final result = results == null || results.isEmpty
            ? null
            : results.first as Map?;
        final asset = result?['assetProfile'] as Map?;
        sector ??= asset?['sector'] as String?;
        industry ??= asset?['industry'] as String?;
        country = asset?['country'] as String?;
        final top = result?['topHoldings'] as Map?;
        sectorShares = _sectorShares(top?['sectorWeightings']);
        topHoldings = _topHoldings(top?['holdings']);
      } catch (e) {
        debugLog('[YahooFinanceApi] Summary profile failed for $query: $e');
      }
    }

    final region = country == null && quoteType == 'EQUITY' && symbol != null
        ? await NasdaqProfileApi.region(symbol)
        : null;
    final profile = DepotAssetProfile(
      sector: _clean(sector),
      industry: _clean(industry),
      // A fund's "country" is its domicile, not its exposure, so it is only
      // used for single securities; funds get countryShares from constituents.
      country:
          quoteType != 'ETF' &&
              quoteType != 'MUTUALFUND' &&
              sectorShares.isEmpty &&
              topHoldings.isEmpty
          ? _clean(country)
          : null,
      region: region,
      sectorShares: sectorShares,
      fetchedAt: DateTime.now(),
    );
    if (profile.isEmpty && topHoldings.isEmpty) return null;
    return (profile: profile, topHoldings: topHoldings);
  }

  static Map? _firstQuote(Map<String, dynamic> json, String query) {
    final quotes = json['quotes'] as List? ?? const [];
    Map? first;
    for (final item in quotes) {
      if (item is! Map) continue;
      first ??= item;
      final symbol = item['symbol'];
      if (symbol is String && symbol.toUpperCase() == query.toUpperCase()) {
        return item;
      }
    }
    return first;
  }

  static Map<String, double> _sectorShares(Object? raw) {
    if (raw is! List) return const {};
    final shares = <String, double>{};
    for (final item in raw) {
      if (item is! Map) continue;
      for (final entry in item.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! num || value <= 0) continue;
        final name = _sectorNames[key.toLowerCase().replaceAll('_', '')] ?? key;
        shares.update(
          name,
          (current) => current + value.toDouble(),
          ifAbsent: () => value.toDouble(),
        );
      }
    }
    final total = shares.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const {};
    return {for (final entry in shares.entries) entry.key: entry.value / total};
  }

  static List<({String symbol, double weight})> _topHoldings(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map &&
            item['symbol'] is String &&
            (item['symbol'] as String).isNotEmpty &&
            item['holdingPercent'] is num)
          (
            symbol: item['symbol'] as String,
            weight: (item['holdingPercent'] as num).toDouble(),
          ),
    ];
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static const Map<String, String> _sectorNames = {
    'technology': 'Technology',
    'financialservices': 'Financial Services',
    'consumercyclical': 'Consumer Cyclical',
    'consumerdefensive': 'Consumer Defensive',
    'healthcare': 'Healthcare',
    'industrials': 'Industrials',
    'energy': 'Energy',
    'basicmaterials': 'Basic Materials',
    'communicationservices': 'Communication Services',
    'utilities': 'Utilities',
    'realestate': 'Real Estate',
  };

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

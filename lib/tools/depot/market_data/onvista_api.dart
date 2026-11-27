import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_asset_profile.dart';
import '../models/depot_bond_profile.dart';
import '../models/depot_dividend.dart';
import '../models/depot_fund_constituent.dart';
import '../models/market_quote.dart';

/// A bond's profile and its coupon schedule as payments per 100 nominal.
typedef OnvistaBond = ({
  DepotBondProfile profile,
  List<DepotDividendEvent> coupons,
});

/// A fund's full country and sector split plus its largest holdings.
typedef OnvistaFundBreakdown = ({
  Map<String, double> countryShares,
  Map<String, double> sectorShares,
  List<DepotFundConstituent> constituents,
});

/// Unofficial, keyless onvista endpoints keyed by ISIN. Unlike Yahoo they
/// publish a fund's complete country weights. Names come back in German.
class OnvistaApi {
  OnvistaApi._();

  static const _timeout = Duration(seconds: 20);
  static final _isin = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');

  static Future<OnvistaFundBreakdown?> fundBreakdown(String isin) async {
    final json = await _getJson('/api/v1/funds/ISIN:$isin/breakdowns', isin);
    return json == null ? null : parseFundBreakdown(json);
  }

  /// A fund's ongoing charges (TER) as a fraction.
  static Future<double?> fundExpenseRatio(String isin) async {
    final json = await _getJson('/api/v1/funds/ISIN:$isin/snapshot', isin);
    final percent = (json?['fundsBaseData'] as Map?)?['ongoingCharges'];
    if (percent is! num) return null;
    final ratio = percent / 100;
    return DepotAssetProfile.isExpenseRatio(ratio) ? ratio : null;
  }

  /// Country of domicile of a stock, in German.
  static Future<String?> stockCountry(String isin) async {
    final json = await _getJson('/api/v1/stocks/ISIN:$isin/snapshot', isin);
    final country = (json?['company'] as Map?)?['nameCountry'];
    return country is String && country.trim().isNotEmpty
        ? country.trim()
        : null;
  }

  static Future<OnvistaBond?> bond(String isin) async {
    final json = await _getJson('/api/v1/bonds/ISIN:$isin/snapshot', isin);
    return json == null ? null : parseBond(json, DateTime.now());
  }

  /// A bond's quote in percent of the nominal, reported in the nominal's
  /// currency so it converts like a price per 100 nominal. No intraday points.
  static Future<MarketQuote> bondQuote(String isin) async {
    final json = await _getJson('/api/v1/bonds/ISIN:$isin/snapshot', isin);
    final quote = json == null ? null : parseBondQuote(json);
    if (quote == null) throw StateError('No onvista bond quote for $isin');
    return quote;
  }

  @visibleForTesting
  static MarketQuote? parseBondQuote(Map<String, dynamic> json) {
    final quote = json['quote'] as Map? ?? const {};
    final price = _number(quote['last']);
    final currency = _text((json['bondsDetails'] as Map?)?['isoCurrency']);
    if (quote['unitType'] != 'PCT' || price == null || currency == null) {
      return null;
    }
    return MarketQuote(
      price: price,
      previousClose: _number(quote['previousLast']) ?? price,
      currency: currency,
      exchange: _text((quote['market'] as Map?)?['name']) ?? 'onvista',
      points: const [],
      dayHigh: _number(quote['high']),
      dayLow: _number(quote['low']),
      yearHigh: _number(quote['highPrice1Year']),
      yearLow: _number(quote['lowPrice1Year']),
      quoteAt: DateTime.tryParse('${quote['datetimeLast']}')?.toLocal(),
    );
  }

  /// Bonds matching an ISIN, WKN or name.
  static Future<List<({String isin, String name})>> searchBonds(
    String query,
  ) async {
    final json = await _get('/api/v1/instruments/query', {
      'searchValue': query.trim(),
    });
    final list = json?['list'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map &&
            item['entityType'] == 'BOND' &&
            item['isin'] is String &&
            item['name'] is String)
          (isin: item['isin'] as String, name: item['name'] as String),
    ];
  }

  @visibleForTesting
  static OnvistaBond? parseBond(Map<String, dynamic> json, DateTime now) {
    final base = json['bondsBaseData'] as Map? ?? const {};
    final details = json['bondsDetails'] as Map? ?? const {};
    final figures = json['bondsFigures'] as Map? ?? const {};
    final issuer = json['bondsIssuer'] as Map? ?? const {};
    final quote = json['quote'] as Map? ?? const {};
    final coupon = _number(details['coupon']);

    final coupons = <DepotDividendEvent>[];
    final periods = <int>[];
    for (final item
        in (json['bondsCouponList'] as Map?)?['list'] as List? ?? const []) {
      if (item is! Map) continue;
      final start = _day(item['datetimeStartCoupon']);
      final end = _day(item['datetimeEndCoupon']);
      final rate = _number(item['coupon']);
      if (start == null || end == null || rate == null || rate <= 0) continue;
      final months = (end.difference(start).inDays / 30.4).round();
      if (months <= 0) continue;
      periods.add(months);
      coupons.add(DepotDividendEvent(exDate: end, amount: rate * months / 12));
    }
    periods.sort();
    final months = periods.isEmpty
        ? _months(base['nameCouponPeriod'])
        : periods[periods.length ~/ 2];

    final percent = quote['unitType'] == 'PCT';
    final profile = DepotBondProfile(
      issuer: _text(issuer['name']),
      country: _text(issuer['nameCountry']),
      currency: _text(details['isoCurrency']),
      coupon: coupon,
      couponMonths: coupon == 0 ? null : months,
      nextCoupon: _day(base['datetimeNextCoupon']),
      maturity: base['perpetual'] == true
          ? null
          : _day(base['datetimeMaturity']),
      callable: base['callable'] == true,
      yieldToMaturity: _number(figures['yieldToMaturity']),
      currentYield: _number(figures['currentYield']),
      duration: _number(figures['modifyDuration']),
      pricePercent: percent ? _number(quote['last']) : null,
      previousPricePercent: percent ? _number(quote['previousLast']) : null,
      priceAt: DateTime.tryParse('${quote['datetimeLast']}')?.toLocal(),
      fetchedAt: now,
    );
    if (profile.currency == null && coupon == null && profile.issuer == null) {
      return null;
    }
    return (
      profile: profile,
      coupons: coupons..sort((a, b) => a.exDate.compareTo(b.exDate)),
    );
  }

  static int? _months(Object? period) {
    if (period is! String) return null;
    final text = period.toLowerCase();
    if (text.contains('halbjahr')) return 6;
    if (text.contains('vierteljahr') || text.contains('quartal')) return 3;
    if (text.contains('jahr')) return 12;
    final count = RegExp(r'(\d+)\s*monat').firstMatch(text);
    if (count != null) return int.parse(count.group(1)!);
    return text.contains('monat') ? 1 : null;
  }

  /// Onvista stamps dates at noon or midnight UTC; the UTC day is the day.
  static DateTime? _day(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value)?.toUtc() : null;
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @visibleForTesting
  static OnvistaFundBreakdown? parseFundBreakdown(Map<String, dynamic> json) {
    final countries = _shares(json['countryBreakdown'], _skippedCountries);
    final sectors = <String, double>{};
    _shares(json['branchBreakdown'], _skippedSectors).forEach((name, share) {
      sectors.update(
        _sectorNames[name] ?? name,
        (current) => current + share,
        ifAbsent: () => share,
      );
    });
    final constituents = <DepotFundConstituent>[];
    for (final item
        in (json['fundsHoldingList'] as Map?)?['list'] as List? ?? const []) {
      if (item is! Map) continue;
      final instrument = item['instrument'] as Map?;
      final name = instrument?['name'];
      final weight = _weight(item['investmentPct']);
      if (name is! String || name.isEmpty || weight == null) continue;
      final isin = instrument?['isin'];
      constituents.add(
        DepotFundConstituent(
          name: name,
          isin: isin is String && isin.isNotEmpty ? isin : null,
          weight: weight,
        ),
      );
    }
    constituents.sort((a, b) => b.weight.compareTo(a.weight));
    if (countries.isEmpty && sectors.isEmpty && constituents.isEmpty) {
      return null;
    }
    return (
      countryShares: countries,
      sectorShares: sectors,
      constituents: constituents,
    );
  }

  static Map<String, double> _shares(Object? breakdown, Set<String> skipped) {
    final list = breakdown is Map ? breakdown['list'] : null;
    if (list is! List) return const {};
    final shares = <String, double>{};
    for (final item in list) {
      if (item is! Map) continue;
      final name = item['nameBreakdown'];
      final weight = _weight(item['investmentPct']);
      if (name is! String || weight == null) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty || skipped.contains(trimmed.toLowerCase())) continue;
      shares.update(
        trimmed,
        (current) => current + weight,
        ifAbsent: () => weight,
      );
    }
    final total = shares.values.fold<double>(0, (a, b) => a + b);
    return total <= 0 || total > 1.001 ? const {} : shares;
  }

  static double? _weight(Object? percent) {
    if (percent is! num || !percent.isFinite || percent <= 0) return null;
    final share = percent / 100;
    return share > 1 ? null : share.toDouble();
  }

  // Cash and catch-all buckets stay unclassified rather than forming a region.
  static const _skippedCountries = {'barmittel', 'andere länder', 'sonstige'};
  static const _skippedSectors = {
    'barmittel',
    'diverse branchen',
    'sonstige',
    'sonstige branchen',
  };

  // Mapped onto Yahoo's names so both sources share one legend.
  static const Map<String, String> _sectorNames = {
    'IT/Telekommunikation': 'Technology',
    'Informationstechnologie': 'Technology',
    'Telekomdienste': 'Communication Services',
    'Telekommunikation': 'Communication Services',
    'Kommunikationsdienste': 'Communication Services',
    'Finanzen': 'Financial Services',
    'Gesundheitswesen': 'Healthcare',
    'Industrie': 'Industrials',
    'Energie': 'Energy',
    'Rohstoffe': 'Basic Materials',
    'Versorger': 'Utilities',
    'Immobilien': 'Real Estate',
    'Konsumgüter zyklisch': 'Consumer Cyclical',
    'Konsumgüter nicht-zyklisch': 'Consumer Defensive',
    'Basiskonsumgüter': 'Consumer Defensive',
    'Konsumgüter': 'Consumer Goods',
  };

  static Future<Map<String, dynamic>?> _getJson(String path, String isin) =>
      _isin.hasMatch(isin) ? _get(path) : Future.value();

  static Future<Map<String, dynamic>?> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    try {
      final client = await AppHttpClient.client;
      final response = await client
          .get(
            Uri.https('api.onvista.de', path, query),
            headers: const {
              'User-Agent': 'Mozilla/5.0',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map<String, dynamic> ? json : null;
    } catch (e) {
      debugLog('[OnvistaApi] $path unavailable: $e');
      return null;
    }
  }
}

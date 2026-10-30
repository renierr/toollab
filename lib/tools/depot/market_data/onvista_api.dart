import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import '../models/depot_fund_constituent.dart';

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

  /// Country of domicile of a stock, in German.
  static Future<String?> stockCountry(String isin) async {
    final json = await _getJson('/api/v1/stocks/ISIN:$isin/snapshot', isin);
    final country = (json?['company'] as Map?)?['nameCountry'];
    return country is String && country.trim().isNotEmpty
        ? country.trim()
        : null;
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

  static Future<Map<String, dynamic>?> _getJson(
    String path,
    String isin,
  ) async {
    if (!_isin.hasMatch(isin)) return null;
    try {
      final client = await AppHttpClient.client;
      final response = await client
          .get(
            Uri.https('api.onvista.de', path),
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

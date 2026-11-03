import 'package:tool_lab/helpers/debug_log.dart';

import 'market_data/yahoo_finance_api.dart';
import 'models/depot_holding.dart';
import 'models/depot_market_search_result.dart';
import 'models/market_quote.dart';
import 'parqet/parqet_asset_lookup.dart';
import 'parsing/security_parser.dart';

class DepotMarketSearch {
  DepotMarketSearch._();

  static Future<List<DepotMarketSearchResult>> search(
    String query, {
    ParqetAssetLookup? assets,
    Future<List<MarketSearchResult>> Function(String)? searchListings,
  }) async {
    final isin = query.trim().toUpperCase();
    final lookup = searchListings ?? YahooFinanceApi.searchListings;
    final matchingSymbols = SecurityParser.isValidIsin(isin)
        ? (assets ?? const ParqetAssetLookup())
              .symbolsForIsin(isin)
              .catchError((_) => <String>{})
        : Future.value(<String>{});
    final listings = [...await lookup(query)];
    final symbols = await matchingSymbols;
    if (symbols.isNotEmpty &&
        !listings.any(
          (result) => symbols.contains(result.symbol.toUpperCase()),
        )) {
      for (final symbol in symbols.take(3)) {
        try {
          final fallback = await lookup(symbol);
          final exact = fallback.where(
            (result) => result.symbol.toUpperCase() == symbol,
          );
          if (exact.isNotEmpty) {
            listings.addAll(exact);
            break;
          }
        } catch (e) {
          debugLog('[DepotMarketSearch] Lookup failed for $symbol: $e');
        }
      }
    }
    return [
      for (final result in listings)
        if (marketQuoteTypes.contains(result.quoteType.toUpperCase()))
          DepotMarketSearchResult(
            symbol: result.symbol,
            name: result.name,
            quoteType: result.quoteType,
            exchange: result.exchange,
            isin: symbols.contains(result.symbol.toUpperCase()) ? isin : null,
          ),
    ];
  }

  static Future<List<String>> holdingSymbols(
    DepotHolding holding, {
    ParqetAssetLookup? assets,
    Future<List<MarketSearchResult>> Function(String)? searchListings,
  }) async {
    if (holding.assetType == DepotAssetType.security) {
      final isin = holding.isin?.trim().toUpperCase();
      if (isin == null || !SecurityParser.isValidIsin(isin)) return [];
      var listings = const <ParqetAssetSymbol>[];
      try {
        listings = await (assets ?? const ParqetAssetLookup()).listingsForIsin(
          isin,
        );
      } catch (e) {
        debugLog('[DepotMarketSearch] Asset lookup failed for $isin: $e');
      }
      final exchange = holding.quoteExchange?.toLowerCase();
      // OTC listings often lack intraday data.
      return {
        if (exchange != null && exchange.isNotEmpty)
          for (final listing in listings)
            if (listing.exchange.toLowerCase() == exchange) listing.symbol,
        for (final listing in listings)
          if (!_isOtc(listing.exchange)) listing.symbol,
        for (final listing in listings)
          if (_isOtc(listing.exchange)) listing.symbol,
      }.toList();
    }
    if (holding.assetType == DepotAssetType.crypto) {
      final symbol = holding.symbol?.toUpperCase();
      if (symbol == null || symbol.isEmpty) return [];
      final listings = await (searchListings ?? YahooFinanceApi.searchListings)(
        symbol,
      );
      return [
        for (final listing in listings)
          if (listing.quoteType.toUpperCase() == 'CRYPTOCURRENCY' &&
              (listing.symbol.toUpperCase() == symbol ||
                  listing.symbol.toUpperCase() == '$symbol-USD'))
            listing.symbol,
      ];
    }
    return [];
  }

  static bool _isOtc(String exchange) {
    final value = exchange.toLowerCase();
    return value == 'pnk' || value.contains('otc');
  }

  static Future<List<String>> fallbackSymbols(
    DepotHolding holding, {
    Future<List<MarketSearchResult>> Function(String)? searchListings,
  }) async {
    if (holding.assetType != DepotAssetType.security) return const [];
    final isin = holding.isin?.trim().toUpperCase();
    if (isin == null || !SecurityParser.isValidIsin(isin)) return const [];
    final lookup = searchListings ?? YahooFinanceApi.searchListings;
    try {
      final listings = await lookup(isin);
      // Yahoo search does not return ISINs; only its best match is usable.
      final match = listings
          .where(
            (listing) => const {
              'EQUITY',
              'ETF',
              'ETC',
              'ETN',
              'MUTUALFUND',
            }.contains(listing.quoteType.toUpperCase()),
          )
          .firstOrNull;
      return match == null ? const [] : [match.symbol];
    } catch (e) {
      debugLog('[DepotMarketSearch] Fallback lookup failed for $isin: $e');
      return const [];
    }
  }
}

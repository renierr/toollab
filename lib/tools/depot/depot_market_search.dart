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
      final isin = holding.isin?.toUpperCase();
      if (isin == null || !SecurityParser.isValidIsin(isin)) return [];
      final listings = await (assets ?? const ParqetAssetLookup())
          .listingsForIsin(isin);
      final exchange = holding.quoteExchange?.toLowerCase();
      return {
        if (exchange != null && exchange.isNotEmpty)
          for (final listing in listings)
            if (listing.exchange.toLowerCase() == exchange) listing.symbol,
        for (final listing in listings) listing.symbol,
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
}

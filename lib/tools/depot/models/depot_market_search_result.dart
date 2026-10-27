import 'depot_holding.dart';

class DepotMarketSearchResult {
  final String symbol;
  final String name;
  final String quoteType;
  final String exchange;
  final String? isin;

  const DepotMarketSearchResult({
    required this.symbol,
    required this.name,
    required this.quoteType,
    required this.exchange,
    this.isin,
  });

  DepotHoldingKind get kind => marketKind(quoteType, name);
}

DepotHoldingKind marketKind(String quoteType, String name) =>
    switch (quoteType.toUpperCase()) {
      'EQUITY' => DepotHoldingKind.of(DepotAssetType.security, name),
      'ETF' || 'ETC' || 'ETN' => DepotHoldingKind.etf,
      'MUTUALFUND' => DepotHoldingKind.fund,
      'CRYPTOCURRENCY' => DepotHoldingKind.crypto,
      _ => DepotHoldingKind.other,
    };

const marketQuoteTypes = {
  'EQUITY',
  'ETF',
  'ETC',
  'ETN',
  'MUTUALFUND',
  'CRYPTOCURRENCY',
};

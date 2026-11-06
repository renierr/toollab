import 'market_quote.dart';

class DepotHoldingTrend {
  final String symbol;
  final String currency;
  final List<MarketPricePoint> points;
  final DateTime fetchedAt;

  /// In [currency], which may differ from the portfolio's.
  final double? dayLow;
  final double? dayHigh;
  final double? yearLow;
  final double? yearHigh;

  const DepotHoldingTrend({
    required this.symbol,
    required this.currency,
    required this.points,
    required this.fetchedAt,
    this.dayLow,
    this.dayHigh,
    this.yearLow,
    this.yearHigh,
  });
}

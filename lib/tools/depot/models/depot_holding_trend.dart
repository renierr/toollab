import 'market_quote.dart';

class DepotHoldingTrend {
  final String symbol;
  final String currency;
  final List<MarketPricePoint> points;
  final DateTime fetchedAt;

  const DepotHoldingTrend({
    required this.symbol,
    required this.currency,
    required this.points,
    required this.fetchedAt,
  });
}

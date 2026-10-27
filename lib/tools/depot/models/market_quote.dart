class MarketPricePoint {
  final DateTime date;
  final double close;

  const MarketPricePoint({required this.date, required this.close});
}

List<MarketPricePoint> marketPointsInLast24Hours(
  Iterable<MarketPricePoint> points,
  DateTime now,
) {
  final cutoff = now.subtract(const Duration(hours: 24));
  return [
    for (final point in points)
      if (!point.date.isBefore(cutoff) &&
          !point.date.isAfter(now) &&
          point.close.isFinite &&
          point.close > 0)
        point,
  ];
}

List<MarketPricePoint> reduceMarketPoints(
  List<MarketPricePoint> points, {
  int limit = 48,
}) {
  assert(limit >= 2);
  if (points.length <= limit) return points;
  return List.unmodifiable([
    for (var index = 0; index < limit; index++)
      points[(index * (points.length - 1) / (limit - 1)).round()],
  ]);
}

class MarketQuote {
  final double price;
  final double previousClose;
  final String currency;
  final String exchange;
  final double? dayHigh;
  final double? dayLow;
  final double? yearHigh;
  final double? yearLow;
  final DateTime? quoteAt;
  final double? quotedDayChangePercent;
  final List<MarketPricePoint> points;

  const MarketQuote({
    required this.price,
    required this.previousClose,
    required this.currency,
    required this.exchange,
    required this.points,
    this.dayHigh,
    this.dayLow,
    this.yearHigh,
    this.yearLow,
    this.quoteAt,
    this.quotedDayChangePercent,
  });

  MarketQuote withReducedPoints() => MarketQuote(
    price: price,
    previousClose: previousClose,
    currency: currency,
    exchange: exchange,
    points: reduceMarketPoints(points),
    dayHigh: dayHigh,
    dayLow: dayLow,
    yearHigh: yearHigh,
    yearLow: yearLow,
    quoteAt: quoteAt,
    quotedDayChangePercent: quotedDayChangePercent,
  );

  double? get dayChangePercent =>
      quotedDayChangePercent ??
      (previousClose <= 0
          ? null
          : (price - previousClose) / previousClose * 100);

  List<MarketPricePoint> pointsSince(Duration window) {
    if (points.length < 2) return points;
    final cutoff = points.last.date.subtract(window);
    final first = points.indexWhere((p) => !p.date.isBefore(cutoff));
    return points.sublist(first < 0 ? points.length - 2 : first);
  }

  double? changeSince(Duration window) {
    final visible = pointsSince(window);
    if (visible.length < 2 || visible.first.close <= 0) return null;
    return (visible.last.close - visible.first.close) /
        visible.first.close *
        100;
  }

  double? changeFrom(double price) {
    if (price <= 0) return null;
    return (this.price - price) / price * 100;
  }
}

class MarketSearchResult {
  final String symbol;
  final String name;
  final String quoteType;
  final String exchange;

  const MarketSearchResult({
    required this.symbol,
    required this.name,
    required this.quoteType,
    required this.exchange,
  });
}

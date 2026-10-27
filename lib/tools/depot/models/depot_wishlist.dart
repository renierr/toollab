import 'depot_holding.dart';

/// A security on the local wishlist. Parqet does not know about it.
class DepotWishlistItem {
  final String symbol;
  final String name;
  final String quoteType;
  final String exchange;
  final String currency;
  final String? isin;
  final double? addedPrice;
  final DateTime addedAt;

  const DepotWishlistItem({
    required this.symbol,
    required this.name,
    required this.quoteType,
    required this.exchange,
    required this.currency,
    required this.addedAt,
    this.addedPrice,
    this.isin,
  });

  DepotHoldingKind get kind => wishlistKind(quoteType, name);

  factory DepotWishlistItem.fromMap(Map<String, Object?> map) =>
      DepotWishlistItem(
        symbol: map['symbol'] as String,
        name: map['name'] as String,
        quoteType: map['quote_type'] as String,
        exchange: map['exchange'] as String,
        currency: map['currency'] as String,
        isin: map['isin'] as String?,
        addedPrice: map['added_price'] as double?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      );

  Map<String, Object?> toMap() => {
    'symbol': symbol,
    'name': name,
    'quote_type': quoteType,
    'exchange': exchange,
    'currency': currency,
    'isin': isin,
    'added_price': addedPrice,
    'added_at': addedAt.millisecondsSinceEpoch,
  };

  DepotWishlistItem withIsin(String isin) => DepotWishlistItem(
    symbol: symbol,
    name: name,
    quoteType: quoteType,
    exchange: exchange,
    currency: currency,
    addedPrice: addedPrice,
    addedAt: addedAt,
    isin: isin,
  );
}

class DepotWishlistSearchResult {
  final String symbol;
  final String name;
  final String quoteType;
  final String exchange;
  final String? isin;

  const DepotWishlistSearchResult({
    required this.symbol,
    required this.name,
    required this.quoteType,
    required this.exchange,
    this.isin,
  });

  DepotHoldingKind get kind => wishlistKind(quoteType, name);
}

class DepotWishlistPoint {
  final DateTime date;
  final double close;

  const DepotWishlistPoint({required this.date, required this.close});
}

class DepotWishlistQuote {
  final double price;
  final double previousClose;
  final String currency;
  final String exchange;
  final double? dayHigh;
  final double? dayLow;
  final double? yearHigh;
  final double? yearLow;
  final DateTime? quoteAt;

  /// Yahoo's own day change, preferred over one derived from the closes.
  final double? quotedDayChangePercent;

  /// One year of daily closes, oldest first.
  final List<DepotWishlistPoint> points;

  const DepotWishlistQuote({
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

  double? get dayChangePercent =>
      quotedDayChangePercent ??
      (previousClose <= 0
          ? null
          : (price - previousClose) / previousClose * 100);

  List<DepotWishlistPoint> pointsSince(Duration window) {
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

DepotHoldingKind wishlistKind(String quoteType, String name) =>
    switch (quoteType.toUpperCase()) {
      'EQUITY' => DepotHoldingKind.of(DepotAssetType.security, name),
      'ETF' || 'ETC' || 'ETN' => DepotHoldingKind.etf,
      'MUTUALFUND' => DepotHoldingKind.fund,
      'CRYPTOCURRENCY' => DepotHoldingKind.crypto,
      _ => DepotHoldingKind.other,
    };

const wishlistQuoteTypes = {
  'EQUITY',
  'ETF',
  'ETC',
  'ETN',
  'MUTUALFUND',
  'CRYPTOCURRENCY',
};

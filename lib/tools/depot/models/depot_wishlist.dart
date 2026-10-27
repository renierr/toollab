import 'depot_holding.dart';
import 'depot_market_search_result.dart';
import 'market_quote.dart';

/// A wishlist security; Parqet does not know about it.
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

class DepotWishlistSyncRecord {
  final String symbol;
  final int updatedAt;
  final bool deleted;

  const DepotWishlistSyncRecord({
    required this.symbol,
    required this.updatedAt,
    required this.deleted,
  });

  factory DepotWishlistSyncRecord.fromMap(Map<String, Object?> map) =>
      DepotWishlistSyncRecord(
        symbol: map['symbol'] as String,
        updatedAt: map['updated_at'] as int,
        deleted: map['deleted'] == 1,
      );
}

typedef DepotWishlistSearchResult = DepotMarketSearchResult;

typedef DepotWishlistPoint = MarketPricePoint;
typedef DepotWishlistQuote = MarketQuote;

DepotHoldingKind wishlistKind(String quoteType, String name) =>
    marketKind(quoteType, name);

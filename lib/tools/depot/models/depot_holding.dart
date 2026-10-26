import 'parqet_json.dart';

enum DepotAssetType {
  security('security'),
  crypto('crypto'),
  commodity('commodity'),
  cash('cash'),
  custom('custom'),
  insurance('insurance'),
  p2p('p2p'),
  realEstate('real_estate');

  final String wire;

  const DepotAssetType(this.wire);

  static DepotAssetType fromWire(Object? value) => values.firstWhere(
    (t) => t.wire == value,
    orElse: () => DepotAssetType.custom,
  );
}

class DepotHolding {
  final String id;
  final String portfolioId;
  final String name;
  final DepotAssetType assetType;
  final String? isin;
  final String? symbol;
  final String? logo;
  final double shares;
  final double purchasePrice;
  final double purchaseValue;
  final double currentPrice;
  final double currentValue;
  final bool isSold;
  final double unrealizedGain;

  /// Percent, as Parqet reports it.
  final double unrealizedReturn;
  final double realizedGain;
  final double dividends;
  final double fees;
  final double taxes;
  final double? xirr;
  final double? ttwror;
  final DateTime? earliestActivity;
  final DateTime? quoteAt;

  const DepotHolding({
    required this.id,
    required this.portfolioId,
    required this.name,
    required this.assetType,
    this.isin,
    this.symbol,
    this.logo,
    required this.shares,
    required this.purchasePrice,
    required this.purchaseValue,
    required this.currentPrice,
    required this.currentValue,
    required this.isSold,
    required this.unrealizedGain,
    required this.unrealizedReturn,
    required this.realizedGain,
    required this.dividends,
    required this.fees,
    required this.taxes,
    this.xirr,
    this.ttwror,
    this.earliestActivity,
    this.quoteAt,
  });

  double get totalGain => unrealizedGain + realizedGain + dividends;

  /// ISIN or crypto symbol, whichever identifies the asset.
  String? get identifier => isin ?? symbol;

  factory DepotHolding.fromJson(String portfolioId, Map<String, dynamic> json) {
    final asset = ParqetJson.object(json['asset']);
    final position = ParqetJson.object(json['position']);
    final performance = ParqetJson.object(json['performance']);
    final unrealized = ParqetJson.inInterval(performance, 'unrealizedGains');
    final kpis = ParqetJson.inInterval(performance, 'kpis');
    final nickname = json['nickname'] as String?;
    return DepotHolding(
      id: json['id'] as String,
      portfolioId: portfolioId,
      name: (nickname?.isNotEmpty ?? false)
          ? nickname!
          : asset['name'] as String? ?? asset['symbol'] as String? ?? '',
      assetType: DepotAssetType.fromWire(asset['type']),
      isin: asset['isin'] as String?,
      symbol: asset['symbol'] as String?,
      logo: json['logo'] as String?,
      shares: ParqetJson.number(position['shares']),
      purchasePrice: ParqetJson.number(position['purchasePrice']),
      purchaseValue: ParqetJson.number(position['purchaseValue']),
      currentPrice: ParqetJson.number(position['currentPrice']),
      currentValue: ParqetJson.number(position['currentValue']),
      isSold: position['isSold'] == true,
      unrealizedGain: ParqetJson.number(unrealized['gainNet']),
      unrealizedReturn: ParqetJson.number(unrealized['returnNet']),
      realizedGain: ParqetJson.number(
        ParqetJson.inInterval(performance, 'realizedGains')['gainNet'],
      ),
      dividends: ParqetJson.number(
        ParqetJson.inInterval(performance, 'dividends')['gainNet'],
      ),
      fees: ParqetJson.number(
        ParqetJson.inInterval(performance, 'fees')['fees'],
      ),
      taxes: ParqetJson.number(
        ParqetJson.inInterval(performance, 'taxes')['taxes'],
      ),
      xirr: ParqetJson.numberOrNull(kpis['xirr']),
      ttwror: ParqetJson.numberOrNull(kpis['ttwror']),
      earliestActivity: ParqetJson.date(json['earliestActivityDate']),
      quoteAt: ParqetJson.date(ParqetJson.object(json['quote'])['datetime']),
    );
  }

  factory DepotHolding.fromMap(Map<String, Object?> map) => DepotHolding(
    id: map['id'] as String,
    portfolioId: map['portfolio_id'] as String,
    name: map['name'] as String,
    assetType: DepotAssetType.fromWire(map['asset_type']),
    isin: map['isin'] as String?,
    symbol: map['symbol'] as String?,
    logo: map['logo'] as String?,
    shares: map['shares'] as double,
    purchasePrice: map['purchase_price'] as double,
    purchaseValue: map['purchase_value'] as double,
    currentPrice: map['current_price'] as double,
    currentValue: map['current_value'] as double,
    isSold: map['is_sold'] == 1,
    unrealizedGain: map['unrealized_gain'] as double,
    unrealizedReturn: map['unrealized_return'] as double,
    realizedGain: map['realized_gain'] as double,
    dividends: map['dividends'] as double,
    fees: map['fees'] as double,
    taxes: map['taxes'] as double,
    xirr: map['xirr'] as double?,
    ttwror: map['ttwror'] as double?,
    earliestActivity: ParqetJson.fromEpoch(map['earliest_activity']),
    quoteAt: ParqetJson.fromEpoch(map['quote_at']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'name': name,
    'asset_type': assetType.wire,
    'isin': isin,
    'symbol': symbol,
    'logo': logo,
    'shares': shares,
    'purchase_price': purchasePrice,
    'purchase_value': purchaseValue,
    'current_price': currentPrice,
    'current_value': currentValue,
    'is_sold': isSold ? 1 : 0,
    'unrealized_gain': unrealizedGain,
    'unrealized_return': unrealizedReturn,
    'realized_gain': realizedGain,
    'dividends': dividends,
    'fees': fees,
    'taxes': taxes,
    'xirr': xirr,
    'ttwror': ttwror,
    'earliest_activity': earliestActivity?.millisecondsSinceEpoch,
    'quote_at': quoteAt?.millisecondsSinceEpoch,
  };
}

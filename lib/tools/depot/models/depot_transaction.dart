import 'depot_holding.dart';
import 'parqet_json.dart';

enum DepotTransactionType {
  buy('buy'),
  sell('sell'),
  dividend('dividend'),
  interest('interest'),
  transferIn('transfer_in'),
  transferOut('transfer_out'),
  feesTaxes('fees_taxes'),
  deposit('deposit'),
  withdrawal('withdrawal');

  final String wire;

  const DepotTransactionType(this.wire);

  static DepotTransactionType? fromWire(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

class DepotTransaction {
  final String id;
  final String portfolioId;
  final String holdingId;
  final DepotTransactionType type;
  final DepotAssetType assetType;
  final DateTime datetime;
  final double shares;
  final double price;
  final double amount;
  final double amountNet;
  final double tax;
  final double fee;
  final String currency;
  final String? broker;
  final double? realizedGain;

  /// Joined from the holdings table; empty when the holding is unknown.
  final String holdingName;

  const DepotTransaction({
    required this.id,
    required this.portfolioId,
    required this.holdingId,
    required this.type,
    required this.assetType,
    required this.datetime,
    required this.shares,
    required this.price,
    required this.amount,
    required this.amountNet,
    required this.tax,
    required this.fee,
    required this.currency,
    this.broker,
    this.realizedGain,
    this.holdingName = '',
  });

  /// Null for an activity type this build does not know yet.
  static DepotTransaction? fromJson(
    String portfolioId,
    Map<String, dynamic> json,
  ) {
    final type = DepotTransactionType.fromWire(json['type']);
    final datetime = ParqetJson.date(json['datetime']);
    if (type == null || datetime == null) return null;
    return DepotTransaction(
      id: json['id'] as String,
      portfolioId: portfolioId,
      holdingId: json['holdingId'] as String? ?? '',
      type: type,
      assetType: DepotAssetType.fromWire(json['holdingAssetType']),
      datetime: datetime,
      shares: ParqetJson.number(json['shares']),
      price: ParqetJson.number(json['price']),
      amount: ParqetJson.number(json['amount']),
      amountNet: ParqetJson.number(json['amountNet']),
      tax: ParqetJson.number(json['tax']),
      fee: ParqetJson.number(json['fee']),
      currency: json['currency'] as String? ?? '',
      broker: json['broker'] as String?,
      realizedGain: ParqetJson.numberOrNull(json['realizedGainsNet']),
    );
  }

  factory DepotTransaction.fromMap(Map<String, Object?> map) =>
      DepotTransaction(
        id: map['id'] as String,
        portfolioId: map['portfolio_id'] as String,
        holdingId: map['holding_id'] as String,
        type:
            DepotTransactionType.fromWire(map['type']) ??
            DepotTransactionType.buy,
        assetType: DepotAssetType.fromWire(map['asset_type']),
        datetime: DateTime.fromMillisecondsSinceEpoch(map['datetime'] as int),
        shares: map['shares'] as double,
        price: map['price'] as double,
        amount: map['amount'] as double,
        amountNet: map['amount_net'] as double,
        tax: map['tax'] as double,
        fee: map['fee'] as double,
        currency: map['currency'] as String,
        broker: map['broker'] as String?,
        realizedGain: map['realized_gain'] as double?,
        holdingName: map['holding_name'] as String? ?? '',
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'holding_id': holdingId,
    'type': type.wire,
    'asset_type': assetType.wire,
    'datetime': datetime.millisecondsSinceEpoch,
    'shares': shares,
    'price': price,
    'amount': amount,
    'amount_net': amountNet,
    'tax': tax,
    'fee': fee,
    'currency': currency,
    'broker': broker,
    'realized_gain': realizedGain,
  };
}

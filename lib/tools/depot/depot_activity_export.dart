import 'dart:typed_data';

import 'depot_csv.dart';
import 'models/depot_transaction.dart';

class DepotActivityExport {
  DepotActivityExport._();

  static Uint8List csv(
    Iterable<DepotTransaction> transactions,
  ) => DepotCsv.encode(
    'date,portfolio_id,activity_id,holding_id,holding,type,asset_type,shares,price,currency,amount,net,realized_gain,tax,fee,broker',
    _rows(transactions),
  );

  static Iterable<List<Object?>> _rows(
    Iterable<DepotTransaction> transactions,
  ) sync* {
    for (final t in transactions) {
      yield <Object?>[
        t.datetime.toIso8601String(),
        t.portfolioId,
        t.id,
        t.holdingId,
        t.holdingName,
        t.type.wire,
        t.assetType.wire,
        t.shares,
        t.price,
        t.currency,
        t.amount,
        t.amountNet,
        t.realizedGain,
        t.tax,
        t.fee,
        t.broker,
      ];
    }
  }
}

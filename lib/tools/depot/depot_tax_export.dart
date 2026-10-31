import 'dart:typed_data';

import 'depot_csv.dart';
import 'models/depot_transaction.dart';

class DepotTaxExport {
  DepotTaxExport._();

  static Uint8List csv(Iterable<DepotTransaction> transactions, int year) {
    return DepotCsv.encode(
      'date,portfolio,holding,type,currency,amount,net,realized_gain,tax,fee',
      _rows(transactions, year),
    );
  }

  static Iterable<List<Object?>> _rows(
    Iterable<DepotTransaction> transactions,
    int year,
  ) sync* {
    for (final t in transactions) {
      if (t.datetime.year == year) {
        yield <Object?>[
          t.datetime.toIso8601String(),
          t.portfolioId,
          t.holdingName,
          t.type.wire,
          t.currency,
          t.amount,
          t.amountNet,
          t.realizedGain,
          t.tax,
          t.fee,
        ];
      }
    }
  }
}

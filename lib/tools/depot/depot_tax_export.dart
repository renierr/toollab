import 'dart:convert';
import 'dart:typed_data';

import 'models/depot_transaction.dart';

class DepotTaxExport {
  DepotTaxExport._();

  static Uint8List csv(Iterable<DepotTransaction> transactions, int year) {
    final out = StringBuffer('\uFEFF')
      ..writeln(
        'date,portfolio,holding,type,currency,amount,net,realized_gain,tax,fee',
      );
    for (final t in transactions) {
      if (t.datetime.year != year) continue;
      final cells = <Object?>[
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
      out.writeln(cells.map(_cell).join(','));
    }
    return Uint8List.fromList(utf8.encode(out.toString()));
  }

  static String _cell(Object? value) {
    var text = value?.toString() ?? '';
    if (value is String && RegExp(r'^\s*[=+\-@\t\r]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}

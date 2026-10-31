import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../depot_import_state.dart';
import '../models/depot_activity.dart';
import '../models/depot_holding.dart';
import '../models/depot_transaction.dart';

/// Turns parsed statements into Parqet Connect activities.
class ParqetActivityUpload {
  ParqetActivityUpload._();

  static String _type(DepotActivityType type) => switch (type) {
    DepotActivityType.buy => DepotTransactionType.buy.wire,
    DepotActivityType.sell => DepotTransactionType.sell.wire,
    DepotActivityType.dividend => DepotTransactionType.dividend.wire,
  };

  static String? _broker(DepotBank bank) => switch (bank) {
    DepotBank.dkb => 'dkb',
    DepotBank.ing => 'ing',
    DepotBank.unknown => null,
  };

  /// Stable per booking, so Parqet drops a second upload of the same PDF.
  static String externalId(DepotActivity a) {
    final digest = sha256.convert(
      utf8.encode(DepotImportState.duplicateKey(a)),
    );
    return 'toollab-${digest.toString().substring(0, 32)}';
  }

  static Map<String, Object?> body(ParsedStatement statement) {
    final a = statement.activity!;
    final date = a.date!;
    // A dividend may come without a share count; Parqet still wants both.
    final shares = a.shares > 0 ? a.shares : 1.0;
    final price = a.price > 0 ? a.price : a.amount / shares;
    // Only ISIN securities are uploaded; insurance/P2P holdings need their
    // dedicated create endpoints and amount-based activities.
    return {
      'type': _type(a.type),
      'assetIdentifierType': 'isin',
      'isin': a.isin,
      // Noon UTC keeps the booking day in every time zone.
      'datetime': DateTime.utc(
        date.year,
        date.month,
        date.day,
        12,
      ).toIso8601String(),
      'shares': shares,
      'price': price,
      'tax': a.tax.abs(),
      'fee': a.fee.abs(),
      'currency': 'EUR',
      'broker': ?_broker(statement.bank),
      'description': statement.fileName,
      'externalId': externalId(a),
    };
  }

  /// Statement ids whose booking already exists in the synced portfolio,
  /// for example from an earlier CSV import.
  static Set<String> alreadyInParqet(
    Iterable<ParsedStatement> statements,
    List<DepotHolding> holdings,
    List<DepotTransaction> transactions,
  ) {
    final isinOf = {
      for (final h in holdings)
        if (h.isin != null) h.id: h.isin!,
    };
    final result = <String>{};
    for (final s in statements) {
      final a = s.activity;
      final date = a?.date;
      if (a == null || date == null) continue;
      final type = _type(a.type);
      for (final t in transactions) {
        if (t.type.wire != type || isinOf[t.holdingId] != a.isin) continue;
        final d = t.datetime;
        if (d.year != date.year || d.month != date.month || d.day != date.day) {
          continue;
        }
        final sameShares = a.shares > 0 && (t.shares - a.shares).abs() < 1e-6;
        final sameAmount = (t.amount - a.amount).abs() <= 0.02;
        if (sameShares || sameAmount) {
          result.add(s.id);
          break;
        }
      }
    }
    return result;
  }
}

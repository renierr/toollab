import '../models/depot_activity.dart';
import 'german_format.dart';
import 'statement_text.dart';

/// Picks the date Parqet should book the activity on: the trade day for a
/// purchase or sale, the payout day for a dividend. The value date only steps
/// in when neither is printed.
class StatementDateParser {
  StatementDateParser._();

  static const _trade = [
    'Schlusstag',
    'Handelstag',
    'Ausführungstag',
    'Geschäftstag',
    'Handelszeit',
    'Orderausführung',
    'Fälligkeit',
  ];
  static const _payout = ['Zahlbarkeitstag', 'Zahltag', 'Zahlbar am', 'Ex-Tag'];
  static const _value = ['Valuta', 'Wertstellung', 'Buchungstag', 'Belegdatum'];

  static DateTime? parse(StatementText text, DepotActivityType type) {
    final order = type == DepotActivityType.dividend
        ? [_payout, _value, _trade]
        : [_trade, _value, _payout];
    for (final labels in order) {
      final date = text.dateFor(labels);
      if (date != null) return date;
    }
    return GermanFormat.parseDate(text.raw);
  }
}

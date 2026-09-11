import 'german_format.dart';
import 'statement_text.dart';

/// The two totals a statement prints: the position value before costs
/// ([gross]) and the amount that actually moved on the account ([total]).
class AmountParser {
  AmountParser._();

  static const _grossGroups = [
    ['Kurswert'],
    ['Bruttobetrag', 'Bruttoertrag', 'Brutto'],
    ['Dividendengutschrift', 'Ertragsgutschrift'],
    ['Zwischensumme'],
  ];

  static const _totalGroups = [
    ['Ausmachender Betrag'],
    ['Zu Ihren Lasten', 'Zu Ihren Gunsten'],
    ['Endbetrag', 'Gesamtbetrag', 'Auszahlungsbetrag'],
    ['Gutschrift'],
  ];

  static Money? gross(StatementText text) => text.firstMoneyOf(_grossGroups);

  static Money? total(StatementText text) => text.firstMoneyOf(_totalGroups);
}

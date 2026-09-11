import 'german_format.dart';
import 'statement_text.dart';

/// The two totals a statement prints: the position value before costs
/// ([gross]) and the amount that actually moved on the account ([total]).
/// Both require an explicit currency on their line, so a bare heading whose
/// lookahead lands on a quantity line ("Stück 10") never answers.
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

  static Money? gross(StatementText text) =>
      text.firstMoneyOf(_grossGroups, requireCurrency: true);

  static Money? total(StatementText text) =>
      text.firstMoneyOf(_totalGroups, requireCurrency: true);
}

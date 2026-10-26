import '../models/depot_activity.dart';
import 'german_format.dart';
import 'statement_text.dart';

/// The per-share price: the execution rate on a trade, the rate per share on a
/// dividend advice. Label groups are ordered specific first, because "Kurs"
/// also occurs inside "Devisenkurs" and "Kurswert".
class PriceParser {
  PriceParser._();

  static const _tradeGroups = [
    ['Ausführungskurs', 'Ausführungspreis', 'Abrech.-Preis'],
    ['Rücknahmepreis', 'Ausgabepreis', 'Rückzahlungskurs'],
    ['Kurs'],
    ['Preis'],
  ];
  static const _tradeExcluding = ['devisenkurs', 'umrechnungskurs', 'kurswert'];

  static const _dividendGroups = [
    ['Dividende pro Stück', 'Dividende pro Anteil', 'Dividende je Aktie'],
    ['Ertrag pro Stück', 'Ausschüttung pro Stück', 'Ausschüttung pro St.'],
    ['Ertrag pro Anteil', 'Ertrag pro St.'],
    ['Ertragsausschüttung per Stück', 'Ausschüttung per Stück'],
    ['Zins-/Dividendensatz', 'Dividendensatz', 'Zinssatz'],
    ['pro Stück', 'je Stück', 'per Stück', 'pro Anteil', 'pro St.'],
  ];

  /// The rate after partial exemption is a tax figure, not what the fund paid.
  static const _dividendExcluding = ['teilfreist'];

  static Money? parse(StatementText text, DepotActivityType type) {
    if (type == DepotActivityType.dividend) {
      return text.firstMoneyOf(_dividendGroups, excluding: _dividendExcluding);
    }
    return text.firstMoneyOf(_tradeGroups, excluding: _tradeExcluding);
  }
}

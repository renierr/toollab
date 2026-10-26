import 'statement_text.dart';

/// The traded share count. Per-share labels are excluded so a dividend advice
/// does not report the dividend rate as a quantity.
class QuantityParser {
  QuantityParser._();

  static const _labels = [
    'Stück',
    'Stk',
    'St.',
    'Nominale',
    'Nennwert',
    'Anteile',
  ];
  static const _excluding = [
    'pro stück',
    'je stück',
    'per stück',
    'pro anteil',
  ];

  static double? parse(StatementText text) =>
      text.numberFor(_labels, excluding: _excluding);
}

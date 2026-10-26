import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/theme/theme.dart';

/// Locale-aware money and percent formatting for the portfolio views.
class DepotFormat {
  final NumberFormat _money;
  final NumberFormat _compactMoney;
  final NumberFormat _wholeMoney;
  final NumberFormat _decimal;
  final NumberFormat _shares;

  DepotFormat(String locale, String currency)
    : _money = NumberFormat.simpleCurrency(locale: locale, name: currency),
      _compactMoney = NumberFormat.compactSimpleCurrency(
        locale: locale,
        name: currency,
      ),
      _wholeMoney = NumberFormat.simpleCurrency(
        locale: locale,
        name: currency,
        decimalDigits: 0,
      ),
      _decimal = NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 2,
      ),
      _shares = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 6;

  factory DepotFormat.of(BuildContext context, String currency) =>
      DepotFormat(Localizations.localeOf(context).toString(), currency);

  String money(double value, {bool signed = false}) =>
      '${signed && value > 0 ? '+' : ''}${_money.format(value)}';

  String compactMoney(double value) => _compactMoney.format(value);

  /// Short money for an axis tick: no cents, a suffix from a thousand up.
  String axisMoney(double value) => value.abs() >= 1000
      ? _compactMoney.format(value)
      : _wholeMoney.format(value);

  /// [value] is already in percent, as Parqet reports returns.
  String percent(double value, {bool signed = true}) =>
      '${signed && value > 0 ? '+' : ''}${_decimal.format(value)} %';

  String shares(double value) => _shares.format(value);

  static Color? gainColor(double value) => value > 0
      ? AppTheme.statusGreen
      : value < 0
      ? AppTheme.statusRed
      : null;
}

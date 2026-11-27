import 'models/depot_activity.dart';

/// Writes the semicolon-separated activity CSV Parqet accepts on import.
/// Values are EUR except for a foreign-currency bond, which Parqet only
/// accepts in its own currency.
class ParqetCsv {
  ParqetCsv._();

  static const String header =
      'date;price;shares;amount;tax;fee;type;assetType;identifier;currency';

  static String build(Iterable<DepotActivity> activities) {
    final buffer = StringBuffer()..writeln(header);
    for (final activity in activities) {
      buffer.writeln(_row(activity));
    }
    return buffer.toString();
  }

  static String _row(DepotActivity a) {
    final rate = a.parqetRate;
    return [
      _date(a.date),
      _number(a.price * rate, 6),
      _number(a.shares, 9),
      _number(a.amount * rate, 2),
      _number(a.tax * rate, 2),
      _number(a.fee * rate, 2),
      a.type.parqetValue,
      'Security',
      a.isin,
      a.parqetCurrency,
    ].join(';');
  }

  static String _date(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Parqet rejects thousands separators and wants a dot decimal. Trailing
  /// zeros are trimmed so a share count keeps its precision without padding.
  static String _number(double value, int maxDecimals) {
    var text = value.abs().toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text.isEmpty ? '0' : text;
  }
}

/// Parqet's relative performance intervals. Every synced figure that depends
/// on a time frame is stored once per period.
enum DepotPeriod {
  today('1d'),
  month1('1m'),
  month3('3m'),
  ytd('ytd'),
  year1('1y'),
  year3('3y'),
  max('max');

  final String wire;

  const DepotPeriod(this.wire);

  static DepotPeriod fromWire(Object? value) =>
      values.firstWhere((p) => p.wire == value, orElse: () => max);
}

typedef DepotPeriodKey = ({String scope, DepotPeriod period});

import 'parqet_json.dart';

/// Portfolio-level performance for one scope: a single portfolio, or all of
/// them combined.
class DepotSummary {
  final String scope;
  final String currency;
  final double valueStart;
  final double valueEnd;
  final double? xirr;
  final double? ttwror;
  final double unrealizedGain;

  /// Percent, as Parqet reports it.
  final double unrealizedReturn;
  final double realizedGain;
  final double dividends;
  final double fees;
  final double taxes;
  final DateTime syncedAt;

  const DepotSummary({
    required this.scope,
    required this.currency,
    required this.valueStart,
    required this.valueEnd,
    this.xirr,
    this.ttwror,
    required this.unrealizedGain,
    required this.unrealizedReturn,
    required this.realizedGain,
    required this.dividends,
    required this.fees,
    required this.taxes,
    required this.syncedAt,
  });

  double get totalGain => unrealizedGain + realizedGain + dividends;

  DepotSummary withScope(String scope) => DepotSummary(
    scope: scope,
    currency: currency,
    valueStart: valueStart,
    valueEnd: valueEnd,
    xirr: xirr,
    ttwror: ttwror,
    unrealizedGain: unrealizedGain,
    unrealizedReturn: unrealizedReturn,
    realizedGain: realizedGain,
    dividends: dividends,
    fees: fees,
    taxes: taxes,
    syncedAt: syncedAt,
  );

  factory DepotSummary.fromJson({
    required String scope,
    required String currency,
    required Map<String, dynamic> performance,
    required DateTime syncedAt,
  }) {
    final valuation = ParqetJson.object(performance['valuation']);
    final unrealized = ParqetJson.inInterval(performance, 'unrealizedGains');
    final kpis = ParqetJson.inInterval(performance, 'kpis');
    return DepotSummary(
      scope: scope,
      currency: currency,
      valueStart: ParqetJson.number(valuation['atIntervalStart']),
      valueEnd: ParqetJson.number(valuation['atIntervalEnd']),
      xirr: ParqetJson.numberOrNull(kpis['xirr']),
      ttwror: ParqetJson.numberOrNull(kpis['ttwror']),
      unrealizedGain: ParqetJson.number(unrealized['gainNet']),
      unrealizedReturn: ParqetJson.number(unrealized['returnNet']),
      realizedGain: ParqetJson.number(
        ParqetJson.inInterval(performance, 'realizedGains')['gainNet'],
      ),
      dividends: ParqetJson.number(
        ParqetJson.inInterval(performance, 'dividends')['gainNet'],
      ),
      fees: ParqetJson.number(
        ParqetJson.inInterval(performance, 'fees')['fees'],
      ),
      taxes: ParqetJson.number(
        ParqetJson.inInterval(performance, 'taxes')['taxes'],
      ),
      syncedAt: syncedAt,
    );
  }

  factory DepotSummary.fromMap(Map<String, Object?> map) => DepotSummary(
    scope: map['scope'] as String,
    currency: map['currency'] as String,
    valueStart: map['value_start'] as double,
    valueEnd: map['value_end'] as double,
    xirr: map['xirr'] as double?,
    ttwror: map['ttwror'] as double?,
    unrealizedGain: map['unrealized_gain'] as double,
    unrealizedReturn: map['unrealized_return'] as double,
    realizedGain: map['realized_gain'] as double,
    dividends: map['dividends'] as double,
    fees: map['fees'] as double,
    taxes: map['taxes'] as double,
    syncedAt: DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int),
  );

  Map<String, Object?> toMap() => {
    'scope': scope,
    'currency': currency,
    'value_start': valueStart,
    'value_end': valueEnd,
    'xirr': xirr,
    'ttwror': ttwror,
    'unrealized_gain': unrealizedGain,
    'unrealized_return': unrealizedReturn,
    'realized_gain': realizedGain,
    'dividends': dividends,
    'fees': fees,
    'taxes': taxes,
    'synced_at': syncedAt.millisecondsSinceEpoch,
  };
}

/// Parqet's relative interval a chart was requested with.
enum DepotChartPeriod {
  max('max'),

  /// Intraday points of the current trading day.
  day('1d');

  final String wire;

  const DepotChartPeriod(this.wire);
}

typedef DepotChartKey = ({String scope, DepotChartPeriod period});

class DepotChartPoint {
  final DateTime date;
  final double value;

  /// Net invested capital up to [date].
  final double capital;
  final double drawdown;

  const DepotChartPoint({
    required this.date,
    required this.value,
    required this.capital,
    required this.drawdown,
  });

  static DepotChartPoint? fromJson(Map<String, dynamic> json) {
    final date = ParqetJson.date(json['date']);
    if (date == null) return null;
    final values = ParqetJson.object(json['values']);
    return DepotChartPoint(
      date: date,
      value: ParqetJson.number(values['history']),
      capital: ParqetJson.number(values['capitalHistory']),
      drawdown: ParqetJson.number(values['drawdown']),
    );
  }

  factory DepotChartPoint.fromMap(Map<String, Object?> map) => DepotChartPoint(
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    value: map['value'] as double,
    capital: map['capital'] as double,
    drawdown: map['drawdown'] as double,
  );

  Map<String, Object?> toMap(DepotChartKey key) => {
    'scope': key.scope,
    'period': key.period.wire,
    'date': date.millisecondsSinceEpoch,
    'value': value,
    'capital': capital,
    'drawdown': drawdown,
  };
}

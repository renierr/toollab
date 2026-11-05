import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'market_data/yahoo_finance_api.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';
import 'models/market_quote.dart';

enum DepotBenchmark {
  off('', ''),
  world('EUNL.DE', 'iShares MSCI World (EUNL.DE)'),
  sp500('SXR8.DE', 'iShares S&P 500 (SXR8.DE)');

  final String symbol;
  final String label;
  const DepotBenchmark(this.symbol, this.label);
}

/// [portfolio] and [benchmark] are indexed to 100; [value] is the depot's
/// money and [shadow] what the same deposits and withdrawals, made on the
/// same days, would be worth in the benchmark.
typedef DepotBenchmarkPoint = ({
  DateTime date,
  double portfolio,
  double benchmark,
  double value,
  double shadow,
});

/// [income] are dividends and interest paid out of the depot; they count as
/// return of the depot and as money taken out of the shadow benchmark, which
/// would have kept them.
List<DepotBenchmarkPoint> compareDepotBenchmark(
  List<DepotChartPoint> chart,
  List<MarketPricePoint> prices, {
  List<(DateTime, double)> income = const [],
}) {
  final sorted = [...prices.where((p) => p.close.isFinite && p.close > 0)]
    ..sort((a, b) => a.date.compareTo(b.date));
  if (chart.length < 2 || sorted.length < 2) return const [];
  final payouts = [...income]..sort((a, b) => a.$1.compareTo(b.$1));
  var payout = 0;
  final result = <DepotBenchmarkPoint>[];
  DepotChartPoint? previous;
  double? base;
  var index = 100.0;
  var units = 0.0;
  var quoteIndex = -1;
  for (final point in chart) {
    final day = DateTime(point.date.year, point.date.month, point.date.day);
    var paid = 0.0;
    while (payout < payouts.length && !payouts[payout].$1.isAfter(day)) {
      if (previous != null) paid += payouts[payout].$2;
      payout++;
    }
    while (quoteIndex + 1 < sorted.length) {
      final next = sorted[quoteIndex + 1].date;
      final nextDay = DateTime(next.year, next.month, next.day);
      if (nextDay.isAfter(day)) break;
      quoteIndex++;
    }
    if (quoteIndex < 0 ||
        day
                .difference(
                  DateTime(
                    sorted[quoteIndex].date.year,
                    sorted[quoteIndex].date.month,
                    sorted[quoteIndex].date.day,
                  ),
                )
                .inDays >
            7 ||
        !point.value.isFinite ||
        point.value <= 0) {
      if (result.isNotEmpty) return const [];
      continue;
    }
    final close = sorted[quoteIndex].close;
    if (previous != null) {
      final newMoney = point.capital - previous.capital;
      final factor = (point.value - newMoney + paid) / previous.value;
      if (!factor.isFinite || factor <= 0) return const [];
      index *= factor;
      if (!index.isFinite) return const [];
      units += (newMoney - paid) / close;
    } else {
      units = point.value / close;
    }
    base ??= close;
    result.add((
      date: point.date,
      portfolio: index,
      benchmark: close / base * 100,
      value: point.value,
      shadow: units * close,
    ));
    previous = point;
  }
  return result.length < 2 ? const [] : result;
}

class DepotBenchmarkState extends ChangeNotifier {
  DepotBenchmarkState({
    Future<MarketQuote> Function(String, DateTime, DateTime)? loader,
  }) : _loader = loader ?? _load;

  final Future<MarketQuote> Function(String, DateTime, DateTime) _loader;
  DepotBenchmark selection = DepotBenchmark.off;

  /// Money with the same deposits instead of both indexed to 100.
  bool inMoney = false;
  List<DepotBenchmarkPoint> points = const [];
  bool loading = false;
  bool failed = false;
  bool currencyMismatch = false;
  List<DepotChartPoint>? _chart;
  String? _currency;
  int _revision = 0;
  bool _disposed = false;

  static Future<MarketQuote> _load(String symbol, DateTime from, DateTime to) =>
      YahooFinanceApi.chartQuote(symbol, from: from, to: to, interval: '1d');

  void select(DepotBenchmark value) {
    if (selection == value) return;
    selection = value;
    _revision++;
    _chart = null;
    points = const [];
    loading = false;
    failed = false;
    currencyMismatch = false;
    notifyListeners();
  }

  void setInMoney(bool value) {
    if (inMoney == value) return;
    inMoney = value;
    notifyListeners();
  }

  bool needsLoad(List<DepotChartPoint> chart, String currency) =>
      selection != DepotBenchmark.off &&
      (!identical(_chart, chart) || _currency != currency);

  void reduceCache() {
    _revision++;
    selection = DepotBenchmark.off;
    _chart = null;
    _currency = null;
    points = const [];
    loading = false;
    failed = false;
    currencyMismatch = false;
  }

  /// Dividends and interest of [transactions], for [compareDepotBenchmark].
  static List<(DateTime, double)> incomeOf(
    List<DepotTransaction> transactions,
  ) => [
    for (final t in transactions)
      if (t.type == DepotTransactionType.dividend ||
          t.type == DepotTransactionType.interest)
        (t.datetime, t.amountNet),
  ];

  Future<void> load(
    List<DepotChartPoint> chart,
    String currency, {
    bool force = false,
    List<(DateTime, double)> income = const [],
  }) async {
    if (_disposed ||
        selection == DepotBenchmark.off ||
        (!force && !needsLoad(chart, currency))) {
      return;
    }
    _chart = chart;
    _currency = currency;
    final revision = ++_revision;
    points = const [];
    failed = false;
    currencyMismatch = currency != 'EUR';
    if (chart.length < 2 || currencyMismatch) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final quote = await _loader(
        selection.symbol,
        chart.first.date.subtract(const Duration(days: 8)),
        chart.last.date.add(const Duration(days: 1)),
      );
      if (_disposed || revision != _revision) return;
      currencyMismatch = quote.currency != currency;
      if (!currencyMismatch) {
        points = compareDepotBenchmark(chart, quote.points, income: income);
      }
    } catch (e) {
      if (_disposed || revision != _revision) return;
      errorLog('[DepotBenchmarkState] Benchmark failed: $e');
      failed = true;
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}

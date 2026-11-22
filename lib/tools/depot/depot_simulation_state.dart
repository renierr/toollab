import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_portfolio_state.dart';
import 'depot_store.dart';
import 'market_data/yahoo_finance_api.dart';
import 'models/depot_advance_lump.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';
import 'simulation/depot_sim_engine.dart';
import 'simulation/depot_sim_inputs.dart';

enum DepotSimProblem { indexFailed, noHistory }

typedef DepotSimRunner = Future<DepotSimResult> Function(DepotSimParams params);
typedef DepotIndexLoader = Future<List<double>> Function(String symbol);

class DepotSimulationState extends ChangeNotifier {
  DepotSimulationState({DepotSimRunner? runner, DepotIndexLoader? indexLoader})
    : _runner = runner ?? _isolateRun,
      _indexLoader = indexLoader ?? _loadIndex;

  /// Below this the own depot history is too short to stand for the future.
  static const int shortHistoryMonths = 120;
  static const Duration _indexMaxAge = Duration(days: 30);
  static const Duration _debounce = Duration(milliseconds: 350);

  final DepotSimRunner _runner;
  final DepotIndexLoader _indexLoader;

  DepotSimInputs _inputs = const DepotSimInputs();
  DepotSimDepotData? _depot;
  DepotSimResult? _result;
  DepotSimProblem? _problem;
  DepotSimStrategy _strategy = DepotSimStrategy.fixed;
  bool _running = false;
  Future<void>? _loading;
  final Map<DepotSimSource, List<double>> _index = {};
  (Object?, Object?, Object?, double)? _depotSource;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;

  DepotSimInputs get inputs => _inputs;
  DepotSimDepotData? get depot => _depot;
  DepotSimResult? get result => _result;
  DepotSimProblem? get problem => _problem;
  DepotSimStrategy get strategy => _strategy;
  bool get running => _running;

  /// Months behind the selected source; null for manual returns.
  int? get historyMonths => switch (_inputs.source) {
    DepotSimSource.manual => null,
    DepotSimSource.depot => _depot?.monthlyReturns.length,
    final source => _index[source]?.length,
  };

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final stored = await DepotStore.instance.simulationInputs();
      if (stored != null && stored.isNotEmpty) {
        _inputs = DepotSimInputs.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        _notify();
      }
    } catch (e) {
      errorLog('[DepotSimulationState] Loading inputs failed: $e');
    }
  }

  /// Takes the depot figures once per synced data set.
  void syncDepot(DepotPortfolioState portfolio) {
    final source = (
      portfolio.holdings,
      portfolio.transactions,
      portfolio.maxChart,
      portfolio.taxAllowance,
    );
    if (_depotSource case final last?
        when identical(last.$1, source.$1) &&
            identical(last.$2, source.$2) &&
            identical(last.$3, source.$3) &&
            last.$4 == source.$4) {
      return;
    }
    _depotSource = source;
    _depot = depotDataOf(portfolio);
    _schedule(immediate: _result == null);
  }

  void setInputs(DepotSimInputs inputs) {
    _inputs = inputs;
    _notify();
    _schedule();
    DepotStore.instance
        .setSimulationInputs(jsonEncode(inputs.toJson()))
        .catchError(
          (Object e) =>
              errorLog('[DepotSimulationState] Saving inputs failed: $e'),
        );
  }

  void setStrategy(DepotSimStrategy strategy) {
    if (strategy == _strategy) return;
    _strategy = strategy;
    _notify();
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    if (immediate) {
      unawaited(_run());
    } else {
      _timer = Timer(_debounce, () => unawaited(_run()));
    }
  }

  Future<void> _run() async {
    final depot = _depot;
    if (depot == null || _disposed) return;
    final revision = ++_revision;
    _running = true;
    _notify();
    try {
      final inputs = _inputs;
      final monthly = await _monthlyReturns(inputs.source, depot);
      if (revision != _revision || _disposed) return;
      final params = DepotSimParams.of(inputs, depot, monthlyReturns: monthly);
      if (inputs.source != DepotSimSource.manual &&
          params.yearReturns.isEmpty) {
        _problem = DepotSimProblem.noHistory;
        _result = null;
        return;
      }
      final result = await _runner(params);
      if (revision != _revision || _disposed) return;
      _result = result;
      _problem = null;
    } catch (e) {
      if (revision != _revision || _disposed) return;
      errorLog('[DepotSimulationState] Simulation failed: $e');
      _problem = DepotSimProblem.indexFailed;
      _result = null;
    } finally {
      if (revision == _revision) {
        _running = false;
        _notify();
      }
    }
  }

  Future<List<double>> _monthlyReturns(
    DepotSimSource source,
    DepotSimDepotData depot,
  ) async {
    _problem = null;
    final symbol = source.symbol;
    if (symbol == null) {
      return source == DepotSimSource.depot ? depot.monthlyReturns : const [];
    }
    final cached = _index[source];
    if (cached != null) return cached;

    List<double>? stored;
    DateTime? fetchedAt;
    try {
      final raw = await DepotStore.instance.simulationIndex(source.name);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
        stored = [
          for (final r in json['returns'] as List) (r as num).toDouble(),
        ];
      }
    } catch (e) {
      errorLog('[DepotSimulationState] Reading index cache failed: $e');
    }
    final fresh =
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _indexMaxAge;
    if (stored != null && fresh) return _index[source] = stored;

    try {
      final loaded = await _indexLoader(symbol);
      await DepotStore.instance.setSimulationIndex(
        source.name,
        jsonEncode({
          'fetchedAt': DateTime.now().toIso8601String(),
          'returns': loaded,
        }),
      );
      return _index[source] = loaded;
    } catch (e) {
      // A stale copy beats none when offline.
      if (stored != null) return _index[source] = stored;
      rethrow;
    }
  }

  static Future<DepotSimResult> _isolateRun(DepotSimParams params) =>
      Isolate.run(() => DepotSimEngine.run(params));

  static Future<List<double>> _loadIndex(String symbol) async {
    final quote = await YahooFinanceApi.chartQuote(
      symbol,
      from: DateTime(1970),
      to: DateTime.now(),
      interval: '1mo',
    );
    return monthlyReturnsOf([for (final p in quote.points) p.close]);
  }

  @visibleForTesting
  static List<double> monthlyReturnsOf(List<double> closes) => [
    for (var i = 1; i < closes.length; i++)
      if (closes[i - 1] > 0 && closes[i] > 0) closes[i] / closes[i - 1] - 1,
  ];

  static DepotSimDepotData depotDataOf(DepotPortfolioState portfolio) {
    final value = portfolio.openValue;
    var exempt = 0.0;
    for (final h in portfolio.holdings) {
      if (h.isSold || h.currentValue <= 0) continue;
      exempt += h.currentValue * (DepotAdvanceLump.partialExemption(h) ?? 0);
    }
    final since = DateTime.now().subtract(const Duration(days: 365));
    var dividends = 0.0;
    for (final t in portfolio.transactions) {
      if (t.type == DepotTransactionType.dividend &&
          t.datetime.isAfter(since)) {
        dividends += t.amount.abs();
      }
    }
    final chart = portfolio.maxChart;
    return DepotSimDepotData(
      value: value,
      invested: chart.isEmpty ? value : chart.last.capital,
      monthlySavings: portfolio.savingsPlans.plans.fold(
        0.0,
        (sum, p) => sum + p.rate,
      ),
      dividendYield: value > 0 ? dividends / value : 0,
      partialExemption: value > 0 ? exempt / value : 0,
      taxAllowance: portfolio.taxAllowance,
      monthlyReturns: _depotMonthlyReturns(chart, portfolio),
    );
  }

  static List<double> _depotMonthlyReturns(
    List<DepotChartPoint> chart,
    DepotPortfolioState portfolio,
  ) {
    if (chart.length < 2) return const [];
    return [
      for (final year in portfolio.monthlyReturns.years.reversed)
        for (final month in year.months)
          if (month != null) month / 100,
    ];
  }

  /// Drops results and index data; inputs stay.
  void reduceCache() {
    _timer?.cancel();
    _revision++;
    _result = null;
    _depot = null;
    _depotSource = null;
    _running = false;
    _index.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _revision++;
    super.dispose();
  }
}

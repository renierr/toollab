import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_parqet_sync.dart';
import 'depot_store.dart';
import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_income_month.dart';
import 'models/depot_period.dart';
import 'models/depot_portfolio.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';
import 'models/depot_year_report.dart';
import 'parqet/parqet_auth.dart';
import 'parqet/parqet_api.dart';
import 'parqet/parqet_exception.dart';

class DepotRangeChange {
  final double valueChange;

  /// Value change less what was paid in or taken out during the range.
  final double gain;

  const DepotRangeChange({required this.valueChange, required this.gain});
}

class DepotPortfolioState extends ChangeNotifier {
  DepotPortfolioState({this.api});

  static const Duration staleAfter = Duration(minutes: 30);

  final DepotStore _store = DepotStore.instance;
  final ParqetApi? api;
  final Map<DepotPeriod, Future<void>> _periodRefreshes = {};

  Future<void>? _loading;
  bool _isLoaded = false;
  bool _disposed = false;
  String _clientId = '';
  bool _isConnected = false;
  bool _isSyncing = false;
  bool _isConnecting = false;
  ParqetException? _error;
  DateTime? _lastSyncAt;

  List<DepotPortfolio> _portfolios = const [];
  String _scope = DepotStore.allScope;
  DepotPeriod _period = DepotPeriod.today;
  DepotSummary? _summary;
  List<DepotChartPoint> _chart = const [];
  DepotRangeChange? _rangeChange;
  List<DepotHolding> _holdings = const [];
  Map<String, DepotHoldingPerformance> _holdingPerformance = const {};
  List<DepotTransaction> _transactions = const [];
  List<DepotYearReport> _yearReports = const [];
  int? _reportYear;

  /// Bumped per period load, so a slow read for an earlier selection cannot
  /// overwrite the current one.
  int _periodLoad = 0;
  int _scopeLoad = 0;

  DepotHoldingFilter _holdingFilter = const DepotHoldingFilter();
  DepotActivityFilter _activityFilter = const DepotActivityFilter();
  List<DepotHolding> _visibleHoldings = const [];
  List<DepotTransaction> _visibleTransactions = const [];

  bool get isLoaded => _isLoaded;
  String get clientId => _clientId;
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing || _periodRefreshes.isNotEmpty;
  bool get isConnecting => _isConnecting;
  ParqetException? get error => _error;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get hasData => _holdings.isNotEmpty || _summary != null;

  /// Every holding and summary figure is synced in this currency.
  String get currency =>
      _summary?.currency ??
      (_portfolios.isEmpty ? 'EUR' : _portfolios.first.currency);

  List<DepotPortfolio> get portfolios => _portfolios;
  String get scope => _scope;
  DepotPeriod get period => _period;
  DepotSummary? get summary => _summary;
  List<DepotChartPoint> get chart => _chart;
  DepotRangeChange? get rangeChange => _rangeChange;
  List<DepotHolding> get holdings => _holdings;
  List<DepotTransaction> get transactions => _transactions;

  /// One report per year with bookings, newest first.
  List<DepotYearReport> get yearReports => _yearReports;

  /// The selected entry of [yearReports]; the newest year until one is picked.
  DepotYearReport? get yearReport {
    final reports = _yearReports;
    if (reports.isEmpty) return null;
    return reports.firstWhere(
      (r) => r.year == _reportYear,
      orElse: () => reports.first,
    );
  }

  void setReportYear(int year) {
    if (year == _reportYear) return;
    _reportYear = year;
    _notify();
  }

  DepotHoldingFilter get holdingFilter => _holdingFilter;
  DepotActivityFilter get activityFilter => _activityFilter;
  List<DepotHolding> get visibleHoldings => _visibleHoldings;
  List<DepotTransaction> get visibleTransactions => _visibleTransactions;

  /// The selected period's figures for [holding], if Parqet had any.
  DepotHoldingPerformance? performanceOf(DepotHolding holding) =>
      _holdingPerformance[DepotHoldingPerformance.keyOf(
        holding.portfolioId,
        holding.id,
      )];

  String? get _portfolioId => _scope == DepotStore.allScope ? null : _scope;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      _clientId = await _store.clientId() ?? '';
      _isConnected = await DepotParqetSync.isConnected();
      _lastSyncAt = await _store.lastSyncAt();
      _holdingFilter = _holdingFilter.copyWith(
        sort: await _store.holdingSort(),
      );
      await _reload();
    } catch (e) {
      errorLog('[DepotPortfolioState] Loading failed: $e');
    }
    _isLoaded = true;
    _notify();
  }

  Future<void> _reload() async {
    final load = ++_scopeLoad;
    final portfolios = await _store.portfolios();
    if (_disposed || load != _scopeLoad) return;
    _portfolios = portfolios;
    if (_scope != DepotStore.allScope &&
        !_portfolios.any((p) => p.id == _scope)) {
      _scope = DepotStore.allScope;
    }
    final scope = _scope;
    final portfolioId = _portfolioId;
    final holdings = await _store.holdings(portfolioId: portfolioId);
    final transactions = await _store.transactions(portfolioId: portfolioId);
    if (_disposed || load != _scopeLoad || scope != _scope) return;
    _holdings = holdings;
    _transactions = transactions;
    _yearReports = _reportsOf(transactions);
    _refilterTransactions();
    await _loadPeriod();
  }

  Future<void> _loadPeriod() async {
    final load = ++_periodLoad;
    final period = _period;
    final portfolioId = _portfolioId;
    final key = (scope: _scope, period: period);
    final summary = await _store.summary(key);
    final chart = await _store.chart(key);
    final performance = await _store.holdingPerformance(
      period,
      portfolioId: portfolioId,
    );
    if (_disposed || load != _periodLoad || key.scope != _scope) return;
    _summary = summary;
    _chart = chart;
    _holdingPerformance = performance;
    _rangeChange = _changeOf(chart) ?? _changeOfSummary(summary);
    _refilterHoldings();
  }

  Future<void> _refreshSelectedPeriodIfStale() async {
    if (_disposed || _isSyncing || !_isConnected || _portfolios.isEmpty) return;
    final period = _period;
    final scope = _scope;
    final summary = await _store.summary((scope: scope, period: period));
    if (_disposed || _isSyncing || !_isConnected) return;
    if (summary != null &&
        DateTime.now().difference(summary.syncedAt) <= staleAfter) {
      return;
    }
    final future = _periodRefreshes[period] ??= _refreshPeriod(period);
    _notify();
    try {
      await future;
    } finally {
      if (identical(_periodRefreshes[period], future)) {
        _periodRefreshes.remove(period);
      }
      _notify();
    }
  }

  Future<void> _refreshPeriod(DepotPeriod period) async {
    try {
      await DepotParqetSync.refreshPeriod(
        period: period,
        portfolios: List.of(_portfolios),
        api: api,
      );
      if (!_disposed && _period == period) {
        await _reload();
        _error = null;
      }
    } catch (e) {
      errorLog('[DepotPortfolioState] Period refresh failed: $e');
      if (_period == period) {
        _error = e is ParqetException
            ? e
            : ParqetException(ParqetErrorKind.invalidResponse, '$e');
      }
    }
  }

  static DepotRangeChange? _changeOf(List<DepotChartPoint> points) {
    if (points.length < 2) return null;
    final first = points.first;
    final last = points.last;
    final valueChange = last.value - first.value;
    return DepotRangeChange(
      valueChange: valueChange,
      gain: valueChange - (last.capital - first.capital),
    );
  }

  /// Today's chart holds a single point, so the change comes from the summary.
  static DepotRangeChange? _changeOfSummary(DepotSummary? summary) =>
      summary == null
      ? null
      : DepotRangeChange(
          valueChange: summary.valueEnd - summary.valueStart,
          gain: summary.totalGain,
        );

  /// Also picks up what a scheduled background run stored meanwhile.
  Future<void> syncIfStale() async {
    await ensureLoaded();
    final storedSync = await _store.lastSyncAt();
    if (storedSync != _lastSyncAt) {
      _lastSyncAt = storedSync;
      await _reload();
      _notify();
    }
    if (!_isConnected) return;
    final last = _lastSyncAt;
    if (last == null || DateTime.now().difference(last) > staleAfter) {
      await sync();
    } else {
      await _refreshSelectedPeriodIfStale();
    }
  }

  /// [full] re-reads every activity instead of only what is newer than the
  /// stored watermark.
  Future<void> sync({bool full = false}) async {
    if (isSyncing || !_isConnected || _disposed) return;
    _isSyncing = true;
    _error = null;
    _notify();
    var completed = false;
    try {
      await DepotParqetSync.run(
        full: full,
        period: _period,
        api: api,
        onPeriodReady: () async {
          if (_disposed) return;
          await _reload();
          _notify();
        },
      );
      _lastSyncAt = await _store.lastSyncAt();
      await _reload();
      completed = true;
    } on ParqetException catch (e) {
      errorLog('[DepotPortfolioState] Sync failed: $e');
      _error = e;
    } catch (e) {
      errorLog('[DepotPortfolioState] Sync failed: $e');
      _error = ParqetException(ParqetErrorKind.invalidResponse, '$e');
    } finally {
      _isSyncing = false;
      _notify();
    }
    if (completed) await _refreshSelectedPeriodIfStale();
  }

  /// Runs the browser login; [responseHtml] is shown in the tab it returns to.
  Future<bool> connect({
    required String clientId,
    required String responseHtml,
  }) async {
    final id = clientId.trim();
    if (id.isEmpty || _isConnecting) return false;
    _isConnecting = true;
    _error = null;
    _notify();
    try {
      await _store.setClientId(id);
      _clientId = id;
      await ParqetAuth.login(clientId: id, responseHtml: responseHtml);
      _isConnected = true;
    } on ParqetException catch (e) {
      errorLog('[DepotPortfolioState] Login failed: $e');
      _error = e;
    } finally {
      _isConnecting = false;
      _notify();
    }
    if (_isConnected) await sync();
    return _isConnected;
  }

  Future<void> disconnect() async {
    await ParqetAuth.clearTokens();
    await _store.clear();
    _isConnected = false;
    _error = null;
    _lastSyncAt = null;
    _scope = DepotStore.allScope;
    await _reload();
    _notify();
  }

  Future<void> setScope(String scope) async {
    if (scope == _scope) return;
    _scope = scope;
    await _reload();
    _notify();
    await _refreshSelectedPeriodIfStale();
  }

  Future<void> setPeriod(DepotPeriod period) async {
    if (period == _period) return;
    _period = period;
    _notify();
    await _loadPeriod();
    _notify();
    await _refreshSelectedPeriodIfStale();
  }

  void setHoldingFilter(DepotHoldingFilter filter) {
    if (filter.sort != _holdingFilter.sort) {
      _store.setHoldingSort(filter.sort);
    }
    _holdingFilter = filter;
    _refilterHoldings();
    _notify();
  }

  void setActivityFilter(DepotActivityFilter filter) {
    _activityFilter = filter;
    _refilterTransactions();
    _notify();
  }

  void _refilterHoldings() {
    _visibleHoldings = _holdings.where(_holdingFilter.matches).toList()
      ..sort((a, b) => _holdingFilter.compare(a, b, performanceOf));
  }

  void _refilterTransactions() {
    _visibleTransactions = _transactions
        .where(_activityFilter.matches)
        .toList();
  }

  /// Base of every holding's weight, whatever the filter shows.
  double get openValue => _holdings
      .where((h) => !h.isSold)
      .fold<double>(0, (sum, h) => sum + h.currentValue);

  /// Current value per holding kind, open positions only.
  Map<DepotHoldingKind, double> get allocation {
    final result = <DepotHoldingKind, double>{};
    for (final h in _holdings) {
      if (h.isSold || h.currentValue <= 0) continue;
      result.update(
        h.kind,
        (v) => v + h.currentValue,
        ifAbsent: () => h.currentValue,
      );
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Net dividends and interest per month, oldest first, for the last [months].
  List<DepotIncomeMonth> incomeByMonth({int months = 12}) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month - months + 1);
    final dividends = List<double>.filled(months, 0);
    final interest = List<double>.filled(months, 0);
    for (final t in _transactions) {
      if (t.datetime.isBefore(first)) continue;
      final index =
          (t.datetime.year - first.year) * 12 + t.datetime.month - first.month;
      if (index < 0 || index >= months) continue;
      switch (t.type) {
        case DepotTransactionType.dividend:
          dividends[index] += t.amountNet;
        case DepotTransactionType.interest:
          interest[index] += t.amountNet;
        default:
          break;
      }
    }
    return [
      for (var i = 0; i < months; i++)
        DepotIncomeMonth(
          month: DateTime(first.year, first.month + i),
          dividends: dividends[i],
          interest: interest[i],
        ),
    ];
  }

  static List<DepotYearReport> _reportsOf(List<DepotTransaction> transactions) {
    final reports = <int, DepotYearReport>{};
    for (final t in transactions) {
      final year = t.datetime.year;
      final report = reports[year] ?? DepotYearReport(year: year);
      reports[year] = switch (t.type) {
        DepotTransactionType.sell => report.add(
          realizedGain: t.realizedGain ?? 0,
          taxes: t.tax,
          fees: t.fee,
          sells: 1,
        ),
        DepotTransactionType.dividend => report.add(
          dividends: t.amountNet,
          taxes: t.tax,
          fees: t.fee,
        ),
        DepotTransactionType.interest => report.add(
          interest: t.amountNet,
          taxes: t.tax,
          fees: t.fee,
        ),
        _ => report.add(taxes: t.tax, fees: t.fee),
      };
    }
    return reports.values.toList()..sort((a, b) => b.year.compareTo(a.year));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

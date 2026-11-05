import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_parqet_sync.dart';
import 'depot_activity_groups.dart';
import 'depot_drawdowns.dart';
import 'depot_net_capital.dart';
import 'depot_return_index.dart';
import 'depot_savings_plans.dart';
import 'depot_store.dart';
import 'depot_work_lease.dart';
import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_income_month.dart';
import 'models/depot_monthly_returns.dart';
import 'models/depot_period.dart';
import 'models/depot_portfolio.dart';
import 'models/depot_summary.dart';
import 'models/depot_tax_year.dart';
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

typedef DepotMover = ({DepotHolding holding, double returnPercent});

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
  List<DepotChartPoint> _maxChart = const [];
  DepotRangeChange? _rangeChange;
  List<DepotHolding> _holdings = const [];
  Map<String, int> _holdingOrder = const {};
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
  List<DepotMover> _movers = const [];
  List<DepotMover> _gainMovers = const [];
  bool _moversByGain = false;
  bool _showRises = false;
  List<DepotTransaction>? _salesSource;
  Set<(String, String)> _salesHoldings = const {};
  List<DepotTransaction>? _plansSource;
  DateTime? _plansDay;
  DepotSavingsPlans _savingsPlans = DepotSavingsPlans.empty;
  bool _flowInPercent = false;
  double _taxAllowance = 1000;
  List<DepotChartPoint>? _returnsChart;
  List<DepotTransaction>? _returnsTransactions;
  DepotDrawdowns _drawdowns = DepotDrawdowns.empty;
  DepotMonthlyReturns _monthlyReturns = DepotMonthlyReturns.empty;
  List<DepotTransaction> _visibleTransactions = const [];
  final Map<(String, int, int), bool> _activityMonthExpansion = {};
  List<DepotTransaction>? _groupedActivitiesSource;
  DepotActivityGroups? _activityGroups;
  List<DepotActivityRow>? _activityRows;
  String? _activityRowsScope;

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

  /// The whole history, whatever period is selected.
  List<DepotChartPoint> get maxChart => _maxChart;

  DepotDrawdowns get drawdowns {
    _updateReturns();
    return _drawdowns;
  }

  DepotMonthlyReturns get monthlyReturns {
    _updateReturns();
    return _monthlyReturns;
  }

  void _updateReturns() {
    if (identical(_maxChart, _returnsChart) &&
        identical(_transactions, _returnsTransactions)) {
      return;
    }
    _returnsChart = _maxChart;
    _returnsTransactions = _transactions;
    final index = depotReturnIndex(_maxChart);
    _drawdowns = DepotDrawdowns.of(_maxChart, index);
    _monthlyReturns = DepotMonthlyReturns.of(_maxChart, index);
  }

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

  /// Up to five gains, then up to five losses of the period among
  /// [visibleHoldings] by return percentage, each largest first.
  List<DepotMover> get movers => _movers;
  List<DepotMover> get gainMovers => _gainMovers;
  bool get moversByGain => _moversByGain;

  void setMoversByGain(bool value) {
    _moversByGain = value;
    _notify();
  }

  bool get showRises => _showRises;

  void setShowRises(bool value) {
    _showRises = value;
    _notify();
  }

  /// Saver's allowance, 1000 single or 2000 joint.
  double get taxAllowance => _taxAllowance;

  void setTaxAllowance(double value) {
    if (value == _taxAllowance) return;
    _taxAllowance = value;
    _store.setTaxAllowance(value);
    _notify();
  }

  DepotTaxYear taxYear(int year) => DepotTaxYear.of(
    year: year,
    transactions: _transactions,
    holdings: _holdings,
    currency: currency,
  );

  bool get flowInPercent => _flowInPercent;

  void setFlowInPercent(bool value) {
    _flowInPercent = value;
    _notify();
  }

  bool hasSalesFor(DepotHolding holding) {
    final source = transactions;
    if (!identical(source, _salesSource)) {
      _salesSource = source;
      _salesHoldings = {
        for (final transaction in source)
          if (transaction.type == DepotTransactionType.sell)
            (transaction.portfolioId, transaction.holdingId),
      };
    }
    return _salesHoldings.contains((holding.portfolioId, holding.id));
  }

  /// Detected from the selected scope's buys; recomputed daily since being
  /// overdue depends on the date.
  DepotSavingsPlans get savingsPlans {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!identical(_transactions, _plansSource) || _plansDay != today) {
      _plansSource = _transactions;
      _plansDay = today;
      _savingsPlans = DepotSavingsPlans.detect(_transactions, now);
    }
    return _savingsPlans;
  }

  List<DepotTransaction> get visibleTransactions => _visibleTransactions;

  List<DepotActivityRow> get activityRows {
    final source = visibleTransactions;
    if (!identical(source, _groupedActivitiesSource)) {
      _groupedActivitiesSource = source;
      _activityGroups = DepotActivityGroups(source);
      _activityRows = null;
    }
    if (_activityRowsScope != _scope) {
      _activityRowsScope = _scope;
      _activityRows = null;
    }
    return _activityRows ??= _activityGroups!.rows(
      isExpanded: (month, initial) =>
          activityMonthExpanded(month, defaultExpanded: initial),
    );
  }

  bool activityMonthExpanded(DateTime month, {required bool defaultExpanded}) =>
      _activityMonthExpansion[(_scope, month.year, month.month)] ??
      defaultExpanded;

  void toggleActivityMonth(DateTime month, {required bool defaultExpanded}) {
    final key = (_scope, month.year, month.month);
    _activityMonthExpansion[key] =
        !(_activityMonthExpansion[key] ?? defaultExpanded);
    _activityRows = null;
    _notify();
  }

  /// The selected period's figures for [holding], if Parqet had any.
  DepotHoldingPerformance? performanceOf(DepotHolding holding) =>
      _holdingPerformance[DepotHoldingPerformance.keyOf(
        holding.portfolioId,
        holding.id,
      )];

  int? orderOf(DepotHolding holding) => _holdingOrder[holding.key];

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
      _taxAllowance = await _store.taxAllowance();
      await _reload();
    } catch (e) {
      errorLog('[DepotPortfolioState] Loading failed: $e');
      _error = _asError(e);
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
    final holdingOrder = await _store.holdingOrder();
    final transactions = await _store.transactions(portfolioId: portfolioId);
    if (_disposed || load != _scopeLoad || scope != _scope) return;
    _holdings = holdings;
    _holdingOrder = holdingOrder;
    _transactions = transactions;
    _yearReports = DepotYearReport.fromTransactions(transactions);
    _refilterTransactions();
    await _loadPeriod();
  }

  Future<void> _loadPeriod() async {
    final load = ++_periodLoad;
    final period = _period;
    final portfolioId = _portfolioId;
    final key = (scope: _scope, period: period);
    final summary = await _store.summary(key);
    final stored = await _store.chart(key);
    final storedMax = period == DepotPeriod.max
        ? stored
        : await _store.chart((scope: key.scope, period: DepotPeriod.max));
    final performance = await _store.holdingPerformance(
      period,
      portfolioId: portfolioId,
    );
    if (_disposed || load != _periodLoad || key.scope != _scope) return;
    final chart = depotNetCapital(stored, _transactions);
    final maxChart = identical(storedMax, stored)
        ? chart
        : depotNetCapital(storedMax, _transactions);
    _summary = summary;
    _chart = chart;
    _maxChart = maxChart;
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
      if (_period == period) _error = _asError(e);
    }
  }

  static ParqetException _asError(Object e) => switch (e) {
    ParqetException() => e,
    DatabaseException() => ParqetException(ParqetErrorKind.localStorage, '$e'),
    _ => ParqetException(ParqetErrorKind.invalidResponse, '$e'),
  };

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
      // Runs on every open; a lease would flash a notification each time.
      await sync(keepAlive: false);
    } else {
      await _refreshSelectedPeriodIfStale();
    }
  }

  /// [full] re-reads every activity instead of only what is newer than the
  /// stored watermark. [keepAlive] holds a wake lock and foreground
  /// notification so the sync survives the screen turning off.
  Future<void> sync({bool full = false, bool keepAlive = true}) async {
    if (isSyncing || !_isConnected || _disposed) return;
    if (keepAlive) {
      return DepotWorkLease.hold(DepotWorkLease.syncText, () => _sync(full));
    }
    return _sync(full);
  }

  Future<void> _sync(bool full) async {
    _isSyncing = true;
    _error = null;
    _notify();
    var completed = false;
    try {
      await _runOrJoin(full);
      _lastSyncAt = await _store.lastSyncAt();
      await _reload();
      completed = true;
    } catch (e) {
      errorLog('[DepotPortfolioState] Sync failed: $e');
      _error = _asError(e);
    } finally {
      _isSyncing = false;
      _notify();
    }
    if (completed) await _refreshSelectedPeriodIfStale();
  }

  /// Waits for a sync already running elsewhere instead of duplicating it;
  /// a [full] one still runs afterwards.
  Future<void> _runOrJoin(bool full) async {
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
    } on DepotSyncRunning {
      debugLog('[DepotPortfolioState] Another sync is running; awaiting it');
      await DepotParqetSync.waitForRunningSync(cancelled: () => _disposed);
      if (full && !_disposed) await _runOrJoin(full);
    }
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

  /// Synced data stays on the device as an offline copy.
  Future<void> disconnect() async {
    await ParqetAuth.clearTokens();
    _isConnected = false;
    _error = null;
    _notify();
  }

  /// Deletes every synced row; a connected account syncs again from scratch.
  Future<void> clearLocalData() async {
    await _store.clear();
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

  Future<void> reorderHolding(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _visibleHoldings.length ||
        newIndex >= _visibleHoldings.length) {
      return;
    }
    final full = List<DepotHolding>.of(_holdings)
      ..sort(
        (a, b) => _holdingFilter.compare(a, b, performanceOf, orderOf: orderOf),
      );
    final matchingIndices = [
      for (var i = 0; i < full.length; i++)
        if (_holdingFilter.matches(full[i])) i,
    ];
    final visible = List<DepotHolding>.of(_visibleHoldings);
    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);
    for (var i = 0; i < matchingIndices.length; i++) {
      full[matchingIndices[i]] = visible[i];
    }

    final inFull = {for (final h in full) h.key};
    final existingSorted = _holdingOrder.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final globalKeys = [
      for (final entry in existingSorted) entry.key,
      for (final h in full)
        if (!_holdingOrder.containsKey(h.key)) h.key,
    ];
    final fullIter = full.iterator;
    final nextOrder = <String, int>{};
    final updates = <DepotHoldingOrder>[];
    for (var i = 0; i < globalKeys.length; i++) {
      final key = globalKeys[i];
      if (inFull.contains(key) && fullIter.moveNext()) {
        final holding = fullIter.current;
        nextOrder[holding.key] = i;
        updates.add(
          DepotHoldingOrder(
            portfolioId: holding.portfolioId,
            holdingId: holding.id,
            position: i,
          ),
        );
      } else {
        nextOrder[key] = i;
        final parts = key.split('/');
        if (parts.length == 2) {
          updates.add(
            DepotHoldingOrder(
              portfolioId: parts[0],
              holdingId: parts[1],
              position: i,
            ),
          );
        }
      }
    }
    _holdingOrder = nextOrder;
    _refilterHoldings();
    _notify();
    await _store.saveHoldingOrder(updates);
  }

  void setActivityFilter(DepotActivityFilter filter) {
    _activityFilter = filter;
    _refilterTransactions();
    _notify();
  }

  void _refilterHoldings() {
    _visibleHoldings = _holdings.where(_holdingFilter.matches).toList()
      ..sort(
        (a, b) => _holdingFilter.compare(a, b, performanceOf, orderOf: orderOf),
      );
    final moves = [
      for (final h in _visibleHoldings)
        if (performanceOf(h)?.returnPercent case final percent?
            when percent != 0)
          (holding: h, returnPercent: percent),
    ];
    final gains = moves.where((m) => m.returnPercent > 0).toList()
      ..sort((a, b) => b.returnPercent.compareTo(a.returnPercent));
    final losses = moves.where((m) => m.returnPercent < 0).toList()
      ..sort((a, b) => a.returnPercent.compareTo(b.returnPercent));
    _movers = [...gains.take(5), ...losses.take(5).toList().reversed];
    final amounts = [
      for (final h in _visibleHoldings)
        if (performanceOf(h)?.gain case final gain? when gain != 0)
          (holding: h, returnPercent: gain),
    ];
    final gainAmounts = amounts.where((m) => m.returnPercent > 0).toList()
      ..sort((a, b) => b.returnPercent.compareTo(a.returnPercent));
    final lossAmounts = amounts.where((m) => m.returnPercent < 0).toList()
      ..sort((a, b) => a.returnPercent.compareTo(b.returnPercent));
    _gainMovers = [
      ...gainAmounts.take(5),
      ...lossAmounts.take(5).toList().reversed,
    ];
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

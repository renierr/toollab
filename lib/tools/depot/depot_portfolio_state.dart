import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_parqet_sync.dart';
import 'depot_store.dart';
import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_period.dart';
import 'models/depot_portfolio.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';
import 'parqet/parqet_auth.dart';
import 'parqet/parqet_exception.dart';

class DepotRangeChange {
  final double valueChange;

  /// Value change less what was paid in or taken out during the range.
  final double gain;

  const DepotRangeChange({required this.valueChange, required this.gain});
}

class DepotPortfolioState extends ChangeNotifier {
  static const Duration staleAfter = Duration(minutes: 30);

  final DepotStore _store = DepotStore.instance;

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

  /// Bumped per period load, so a slow read for an earlier selection cannot
  /// overwrite the current one.
  int _periodLoad = 0;

  DepotHoldingFilter _holdingFilter = const DepotHoldingFilter();
  DepotActivityFilter _activityFilter = const DepotActivityFilter();
  List<DepotHolding> _visibleHoldings = const [];
  List<DepotTransaction> _visibleTransactions = const [];

  bool get isLoaded => _isLoaded;
  String get clientId => _clientId;
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
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
    _portfolios = await _store.portfolios();
    if (_scope != DepotStore.allScope &&
        !_portfolios.any((p) => p.id == _scope)) {
      _scope = DepotStore.allScope;
    }
    _holdings = await _store.holdings(portfolioId: _portfolioId);
    _transactions = await _store.transactions(portfolioId: _portfolioId);
    _refilterTransactions();
    await _loadPeriod();
  }

  Future<void> _loadPeriod() async {
    final load = ++_periodLoad;
    final key = (scope: _scope, period: _period);
    final summary = await _store.summary(key);
    final chart = await _store.chart(key);
    final performance = await _store.holdingPerformance(
      _period,
      portfolioId: _portfolioId,
    );
    if (load != _periodLoad) return;
    _summary = summary;
    _chart = chart;
    _holdingPerformance = performance;
    _rangeChange = _changeOf(chart);
    _refilterHoldings();
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
    }
  }

  Future<void> sync() async {
    if (_isSyncing || !_isConnected) return;
    _isSyncing = true;
    _error = null;
    _notify();
    try {
      await DepotParqetSync.run();
      _lastSyncAt = await _store.lastSyncAt();
      await _reload();
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
  }

  Future<void> setPeriod(DepotPeriod period) async {
    if (period == _period) return;
    _period = period;
    _notify();
    await _loadPeriod();
    _notify();
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

  /// Current value per asset type, open positions only.
  Map<DepotAssetType, double> get allocation {
    final result = <DepotAssetType, double>{};
    for (final h in _holdings) {
      if (h.isSold || h.currentValue <= 0) continue;
      result.update(
        h.assetType,
        (v) => v + h.currentValue,
        ifAbsent: () => h.currentValue,
      );
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Net dividends and interest per month, oldest first, for the last [months].
  List<({DateTime month, double amount})> incomeByMonth({int months = 12}) {
    final now = DateTime.now();
    final buckets = [
      for (var i = months - 1; i >= 0; i--)
        (month: DateTime(now.year, now.month - i), amount: 0.0),
    ];
    final first = buckets.first.month;
    for (final t in _transactions) {
      if (t.type != DepotTransactionType.dividend &&
          t.type != DepotTransactionType.interest) {
        continue;
      }
      if (t.datetime.isBefore(first)) continue;
      final index =
          (t.datetime.year - first.year) * 12 + t.datetime.month - first.month;
      if (index < 0 || index >= buckets.length) continue;
      final bucket = buckets[index];
      buckets[index] = (
        month: bucket.month,
        amount: bucket.amount + t.amountNet,
      );
    }
    return buckets;
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

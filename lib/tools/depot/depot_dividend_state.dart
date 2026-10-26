import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'dividends/depot_dividend_calendar.dart';
import 'dividends/yahoo_finance_api.dart';
import 'models/depot_dividend.dart';
import 'models/depot_holding.dart';
import 'models/depot_transaction.dart';

class DepotDividendState extends ChangeNotifier {
  static const Duration staleAfter = Duration(hours: 24);
  static const _parallelRequests = 4;
  static const _kinds = {
    DepotHoldingKind.stock,
    DepotHoldingKind.etf,
    DepotHoldingKind.fund,
  };

  final DepotStore _store = DepotStore.instance;

  Future<void>? _loading;
  bool _disposed = false;
  bool _isFetching = false;
  int _failedCount = 0;
  Map<String, DepotDividendAsset> _assets = const {};

  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  DepotDividendCalendar? _calendar;
  List<DepotHolding>? _calendarHoldings;
  List<DepotTransaction>? _calendarTransactions;
  Map<String, DepotDividendAsset>? _calendarAssets;
  DateTime? _calendarDay;

  bool get isFetching => _isFetching;

  /// Holdings whose data could not be loaded in the last refresh.
  int get failedCount => _failedCount;
  int get year => _year;
  int get month => _month;

  DateTime? get fetchedAt {
    DateTime? latest;
    for (final a in _assets.values) {
      if (latest == null || a.fetchedAt.isAfter(latest)) latest = a.fetchedAt;
    }
    return latest;
  }

  /// Rebuilt only when one of its inputs or the day changed.
  DepotDividendCalendar calendarFor(
    List<DepotHolding> holdings,
    List<DepotTransaction> transactions,
  ) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final cached = _calendar;
    if (cached != null &&
        identical(holdings, _calendarHoldings) &&
        identical(transactions, _calendarTransactions) &&
        identical(_assets, _calendarAssets) &&
        day == _calendarDay) {
      return cached;
    }
    _calendarHoldings = holdings;
    _calendarTransactions = transactions;
    _calendarAssets = _assets;
    _calendarDay = day;
    return _calendar = DepotDividendCalendar.build(
      holdings: holdings,
      transactions: transactions,
      assets: _assets,
      now: now,
    );
  }

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      _assets = await _store.dividendAssets();
    } catch (e) {
      errorLog('[DepotDividendState] Loading failed: $e');
    }
    _notify();
  }

  void setYear(int year) {
    if (year == _year) return;
    _year = year;
    _notify();
  }

  void selectMonth(int month) {
    if (month == _month) return;
    _month = month;
    _notify();
  }

  /// Loads dividend data for open securities whose cache is missing, stale
  /// or in another currency; [force] reloads all of them.
  Future<void> refresh({
    required List<DepotHolding> holdings,
    required String currency,
    bool force = false,
  }) async {
    await ensureLoaded();
    if (_isFetching) return;
    final now = DateTime.now();
    final targets = <String, DepotHolding>{};
    for (final h in holdings) {
      final key = h.identifier;
      if (key == null || h.isSold || !_kinds.contains(h.kind)) continue;
      final cached = _assets[key];
      if (force ||
          cached == null ||
          cached.fxCurrency != currency ||
          now.difference(cached.fetchedAt) > staleAfter) {
        targets[key] = h;
      }
    }
    if (targets.isEmpty) return;

    _isFetching = true;
    _failedCount = 0;
    _notify();
    try {
      final session =
          targets.values.any((h) => h.kind == DepotHoldingKind.stock)
          ? await YahooFinanceApi.session()
          : null;
      final rates = <String, Future<double>>{};
      final entries = targets.entries.toList();
      for (var i = 0; i < entries.length; i += _parallelRequests) {
        final chunk = entries.skip(i).take(_parallelRequests);
        await Future.wait([
          for (final e in chunk)
            _fetch(e.key, e.value, currency, session, rates),
        ]);
      }
    } finally {
      _isFetching = false;
      _notify();
    }
  }

  Future<void> _fetch(
    String key,
    DepotHolding holding,
    String currency,
    YahooSession? session,
    Map<String, Future<double>> rates,
  ) async {
    try {
      final symbol =
          await YahooFinanceApi.symbolFor(key) ??
          (holding.symbol == null || holding.symbol == key
              ? null
              : await YahooFinanceApi.symbolFor(holding.symbol!));
      var asset = DepotDividendAsset(
        key: key,
        symbol: symbol,
        currency: currency,
        fxCurrency: currency,
        fxRate: 1,
        fetchedAt: DateTime.now(),
      );
      if (symbol != null) {
        final dividends = await YahooFinanceApi.dividends(symbol);
        final assetCurrency = dividends.currency.isEmpty
            ? currency
            : dividends.currency;
        final rate = await rates.putIfAbsent(
          assetCurrency,
          () => YahooFinanceApi.fxRate(assetCurrency, currency),
        );
        YahooNextDividend? next;
        if (session != null && holding.kind == DepotHoldingKind.stock) {
          try {
            next = await YahooFinanceApi.nextDividend(symbol, session);
          } on YahooFinanceException catch (e) {
            debugLog('[DepotDividendState] No calendar for $symbol: $e');
          }
        }
        asset = DepotDividendAsset(
          key: key,
          symbol: symbol,
          currency: assetCurrency,
          fxCurrency: currency,
          fxRate: rate,
          nextExDate: next?.exDate,
          nextPayDate: next?.payDate,
          fetchedAt: asset.fetchedAt,
          events: dividends.events,
        );
      }
      await _store.saveDividendAsset(asset);
      _assets = {..._assets, key: asset};
    } catch (e) {
      errorLog('[DepotDividendState] Fetching $key failed: $e');
      _failedCount++;
    }
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

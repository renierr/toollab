import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'market_data/yahoo_finance_api.dart';
import 'depot_market_search.dart';
import 'models/depot_holding.dart';
import 'models/depot_holding_trend.dart';
import 'models/market_quote.dart';

class DepotHoldingTrendState extends ChangeNotifier {
  DepotHoldingTrendState({
    Future<List<String>> Function(DepotHolding)? resolve,
    Future<MarketQuote> Function(String)? quote,
    DateTime Function()? now,
  }) : _resolve = resolve ?? DepotMarketSearch.holdingSymbols,
       _quote = quote ?? YahooFinanceApi.intradayQuote,
       _now = now ?? DateTime.now;

  static const _maxConcurrent = 4;
  static const _maxCacheEntries = 128;
  static const _freshFor = Duration(minutes: 15);
  static const _retryAfter = Duration(minutes: 15);
  final Future<List<String>> Function(DepotHolding) _resolve;
  final Future<MarketQuote> Function(String) _quote;
  final DateTime Function() _now;
  final Map<String, DepotHoldingTrend> _trends = {};
  final Map<String, DateTime> _failed = {};
  final Map<String, DepotHolding> _queue = {};
  final Map<String, int> _active = {};
  final Map<String, Set<bool Function()>> _observers = {};
  Timer? _expiryTimer;
  int _revision = 0;
  bool _disposed = false;

  static String? keyOf(DepotHolding holding) {
    if (holding.isSold) return null;
    if (holding.assetType == DepotAssetType.security &&
        holding.isin != null &&
        holding.isin!.isNotEmpty) {
      return 'security:${holding.isin!.toUpperCase()}';
    }
    if (holding.assetType == DepotAssetType.crypto &&
        holding.symbol != null &&
        holding.symbol!.isNotEmpty) {
      return 'crypto:${holding.symbol!.toUpperCase()}';
    }
    return null;
  }

  DepotHoldingTrend? trendFor(DepotHolding holding) => _trends[keyOf(holding)];

  void ensure(DepotHolding holding, {required bool Function() visible}) {
    final key = keyOf(holding);
    if (_disposed || key == null) return;
    _pruneExpired();
    final active = _active[key];
    if (active != null) {
      _observers.putIfAbsent(key, () => {}).add(visible);
      if (active != _revision) _queue[key] = holding;
      return;
    }
    final cached = _trends[key];
    if (cached != null && _now().difference(cached.fetchedAt) < _freshFor) {
      return;
    }
    final failed = _failed[key];
    if (failed != null && _now().difference(failed) < _retryAfter) return;
    _observers.putIfAbsent(key, () => {}).add(visible);
    _queue[key] = holding;
    _drain();
  }

  void _drain() {
    while (!_disposed && _active.length < _maxConcurrent && _queue.isNotEmpty) {
      final key = _queue.keys
          .where((key) => !_active.containsKey(key))
          .firstOrNull;
      if (key == null) return;
      final holding = _queue.remove(key)!;
      if (!_isVisible(key)) {
        _observers.remove(key);
        continue;
      }
      _active[key] = _revision;
      unawaited(_load(key, holding, _revision));
    }
  }

  bool _isVisible(String key) =>
      _observers[key]?.any((visible) => visible()) ?? false;

  Future<void> _load(String key, DepotHolding holding, int revision) async {
    try {
      final symbols = await _resolve(holding);
      if (_disposed || revision != _revision || !_isVisible(key)) return;
      for (final symbol in symbols.take(3)) {
        if (_disposed || revision != _revision || !_isVisible(key)) return;
        try {
          final quote = await _quote(symbol);
          if (_disposed || revision != _revision) return;
          final points = marketPointsInLast24Hours(quote.points, _now());
          if (points.length < 2) continue;
          _trends.remove(key);
          _trends[key] = DepotHoldingTrend(
            symbol: symbol,
            currency: quote.currency,
            points: List.unmodifiable(points),
            fetchedAt: _now(),
          );
          _failed.remove(key);
          _trimCache();
          _scheduleExpiry();
          notifyListeners();
          return;
        } catch (e) {
          debugLog('[DepotHoldingTrendState] No chart for $symbol: $e');
        }
      }
      throw const FormatException('No confirmed chart');
    } catch (e) {
      if (!_disposed && revision == _revision) {
        _failed.remove(key);
        _failed[key] = _now();
        _trimCache();
        _scheduleExpiry();
        debugLog('[DepotHoldingTrendState] Trend unavailable for $key: $e');
      }
    } finally {
      if (_active[key] == revision) _active.remove(key);
      if (!_queue.containsKey(key)) _observers.remove(key);
      _drain();
    }
  }

  void _trimCache() {
    while (_trends.length > _maxCacheEntries) {
      final key = _trends.keys.first;
      _trends.remove(key);
    }
    while (_failed.length > _maxCacheEntries) {
      final key = _failed.keys.first;
      _failed.remove(key);
    }
  }

  void _pruneExpired() {
    final now = _now();
    for (final entry in _trends.entries.toList()) {
      if (now.difference(entry.value.fetchedAt) >= _freshFor) {
        _trends.remove(entry.key);
      }
    }
    for (final entry in _failed.entries.toList()) {
      if (now.difference(entry.value) >= _retryAfter) {
        _failed.remove(entry.key);
      }
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    DateTime? next;
    for (final time in [
      for (final trend in _trends.values) trend.fetchedAt.add(_freshFor),
      for (final failure in _failed.values) failure.add(_retryAfter),
    ]) {
      if (next == null || time.isBefore(next)) next = time;
    }
    if (next == null || _disposed) return;
    final delay = next.difference(_now());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      final previous = _trends.length;
      _pruneExpired();
      _scheduleExpiry();
      if (!_disposed && _trends.length != previous) notifyListeners();
    });
  }

  void reduceCache() {
    if (_disposed) return;
    _revision++;
    _queue.clear();
    _observers.clear();
    _pruneExpired();
    for (final entry in _trends.entries.toList()) {
      final trend = entry.value;
      _trends[entry.key] = DepotHoldingTrend(
        symbol: trend.symbol,
        currency: trend.currency,
        points: reduceMarketPoints(trend.points),
        fetchedAt: trend.fetchedAt,
      );
    }
    _trimCache();
    _scheduleExpiry();
  }

  void clear() {
    _revision++;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _trends.clear();
    _failed.clear();
    _queue.clear();
    _observers.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}

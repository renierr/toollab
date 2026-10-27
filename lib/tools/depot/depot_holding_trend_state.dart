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
  static const _freshFor = Duration(minutes: 15);
  static const _retryAfter = Duration(minutes: 15);
  final Future<List<String>> Function(DepotHolding) _resolve;
  final Future<MarketQuote> Function(String) _quote;
  final DateTime Function() _now;
  final Map<String, DepotHoldingTrend> _trends = {};
  final Map<String, DateTime> _failed = {};
  final Map<String, DepotHolding> _queue = {};
  final Map<String, Set<bool Function()>> _observers = {};
  final Set<String> _active = {};
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
    if (_active.contains(key)) {
      _observers.putIfAbsent(key, () => {}).add(visible);
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
      final key = _queue.keys.first;
      final holding = _queue.remove(key)!;
      if (!_isVisible(key)) {
        _observers.remove(key);
        continue;
      }
      _active.add(key);
      unawaited(_load(key, holding));
    }
  }

  bool _isVisible(String key) =>
      _observers[key]?.any((visible) => visible()) ?? false;

  Future<void> _load(String key, DepotHolding holding) async {
    try {
      final symbols = await _resolve(holding);
      if (_disposed || !_isVisible(key)) return;
      for (final symbol in symbols.take(3)) {
        if (_disposed || !_isVisible(key)) return;
        try {
          final quote = await _quote(symbol);
          if (_disposed) return;
          final points = marketPointsInLast24Hours(quote.points, _now());
          if (points.length < 2) break;
          _trends[key] = DepotHoldingTrend(
            symbol: symbol,
            currency: quote.currency,
            points: List.unmodifiable(points),
            fetchedAt: _now(),
          );
          _failed.remove(key);
          notifyListeners();
          return;
        } catch (e) {
          debugLog('[DepotHoldingTrendState] No chart for $symbol: $e');
        }
      }
      throw const FormatException('No confirmed chart');
    } catch (e) {
      if (!_disposed) {
        _failed[key] = _now();
        debugLog('[DepotHoldingTrendState] Trend unavailable for $key: $e');
      }
    } finally {
      _active.remove(key);
      _observers.remove(key);
      _drain();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    _observers.clear();
    super.dispose();
  }
}

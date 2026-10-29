import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'market_data/yahoo_finance_api.dart';
import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';

/// Sector, industry and region metadata per holding, fetched from Yahoo and
/// cached in the tool database.
class DepotAllocationState extends ChangeNotifier {
  DepotAllocationState({
    Future<YahooAssetProfile?> Function(String query, YahooSession? session)?
    profileLoader,
    Future<YahooSession?> Function()? sessionLoader,
  }) : _profileLoader = profileLoader ?? _loadProfile,
       _sessionLoader = sessionLoader ?? YahooFinanceApi.session;

  static const Duration staleAfter = Duration(days: 30);
  static const int _parallelRequests = 3;
  static const int _maxConstituents = 10;

  final DepotStore _store = DepotStore.instance;
  final Future<YahooAssetProfile?> Function(String, YahooSession?)
  _profileLoader;
  final Future<YahooSession?> Function() _sessionLoader;

  Map<String, DepotAssetProfile> _profiles = const {};
  final Set<String> _pending = {};
  final Set<String> _failed = {};
  Future<void>? _cacheLoad;
  bool _cacheLoaded = false;
  bool _isFetching = false;
  bool _disposed = false;
  int _generation = 0;

  bool get isLoaded => _cacheLoaded;
  bool get isFetching => _isFetching;

  DepotAssetProfile? profileOf(DepotHolding holding) =>
      _profiles[_keyOf(holding)];

  static Future<YahooAssetProfile?> _loadProfile(
    String query,
    YahooSession? session,
  ) => YahooFinanceApi.assetProfile(query, session: session);

  static String? _keyOf(DepotHolding holding) {
    final isin = holding.isin?.trim();
    if (isin != null && isin.isNotEmpty) return isin;
    final symbol = holding.symbol?.trim();
    if (symbol != null && symbol.isNotEmpty) return symbol;
    return null;
  }

  Future<void> ensureProfiles(
    Iterable<DepotHolding> holdings, {
    bool force = false,
  }) async {
    if (_disposed) return;
    await _ensureCache();
    if (_disposed || _isFetching) return;

    final now = DateTime.now();
    final generation = _generation;
    final targets = <String, DepotHolding>{};
    for (final holding in holdings) {
      if (holding.isSold || holding.currentValue <= 0) continue;
      final key = _keyOf(holding);
      if (key == null || _pending.contains(key)) continue;
      final cached = _profiles[key];
      final fresh =
          cached != null && now.difference(cached.fetchedAt) < staleAfter;
      if (!force && (fresh || _failed.contains(key))) continue;
      targets[key] = holding;
    }
    if (targets.isEmpty) return;

    _isFetching = true;
    _notify();
    var changed = false;
    try {
      final session = await _sessionLoader();
      final entries = targets.entries.toList();
      for (var start = 0; start < entries.length; start += _parallelRequests) {
        if (_disposed || generation != _generation) break;
        final results = await Future.wait([
          for (final entry in entries.skip(start).take(_parallelRequests))
            _fetch(entry.key, entry.value, session, generation),
        ]);
        changed = results.any((fetched) => fetched) || changed;
      }
    } catch (e) {
      errorLog('[DepotAllocationState] Fetching profiles failed: $e');
    } finally {
      if (changed && !_disposed) {
        try {
          await _store.saveAssetProfiles(_profiles);
        } catch (e) {
          errorLog('[DepotAllocationState] Saving profiles failed: $e');
        }
      }
      if (!_disposed && generation == _generation) {
        _isFetching = false;
        _notify();
      }
    }
  }

  /// Re-reads every position's profile, used by pull-to-refresh.
  Future<void> refresh(Iterable<DepotHolding> holdings) async {
    _failed.clear();
    await ensureProfiles(holdings, force: true);
  }

  Future<void> _ensureCache() => _cacheLoad ??= _loadCache();

  Future<void> _loadCache() async {
    try {
      final cached = await _store.assetProfiles();
      if (_disposed) return;
      _profiles = {...cached, ..._profiles};
    } catch (e) {
      errorLog('[DepotAllocationState] Loading cached profiles failed: $e');
    }
    _cacheLoaded = true;
    _notify();
  }

  Future<bool> _fetch(
    String key,
    DepotHolding holding,
    YahooSession? session,
    int generation,
  ) async {
    if (!_pending.add(key)) return false;
    try {
      final query = _keyOf(holding) ?? key;
      final result = await _profileLoader(query, session);
      if (_disposed || generation != _generation) return false;
      if (result == null) {
        _failed.add(key);
        return false;
      }
      var profile = result.profile;
      if (profile.countryShares.isEmpty && result.topHoldings.isNotEmpty) {
        final shares = await _countryShares(
          result.topHoldings,
          session,
          generation,
        );
        profile = profile.copyWith(countryShares: shares);
      }
      if (_disposed || generation != _generation) return false;
      _profiles = {..._profiles, key: profile};
      _failed.remove(key);
      return true;
    } catch (e) {
      _failed.add(key);
      errorLog('[DepotAllocationState] Profile failed for $key: $e');
      return false;
    } finally {
      _pending.remove(key);
    }
  }

  /// A fund's region mix is approximated from the domicile of its largest
  /// constituents, because Yahoo does not publish fund country weights.
  Future<Map<String, double>> _countryShares(
    List<({String symbol, double weight})> topHoldings,
    YahooSession? session,
    int generation,
  ) async {
    final countries = <String, double>{};
    var total = 0.0;
    final entries = topHoldings.take(_maxConstituents).toList();
    for (var start = 0; start < entries.length; start += _parallelRequests) {
      if (_disposed || generation != _generation) break;
      final loaded = await Future.wait([
        for (final entry in entries.skip(start).take(_parallelRequests))
          _constituentCountry(entry.symbol, session),
      ]);
      for (var i = 0; i < loaded.length; i++) {
        final country = loaded[i];
        if (country == null) continue;
        final weight = entries[start + i].weight;
        countries.update(
          country,
          (current) => current + weight,
          ifAbsent: () => weight,
        );
        total += weight;
      }
    }
    if (total <= 0) return const {};
    return {
      for (final entry in countries.entries) entry.key: entry.value / total,
    };
  }

  Future<String?> _constituentCountry(
    String symbol,
    YahooSession? session,
  ) async {
    final cached = _profiles[symbol];
    if (cached?.country != null) return cached?.country;
    if (!_pending.add(symbol)) return null;
    try {
      final result = await _profileLoader(symbol, session);
      if (result == null || _disposed) return null;
      _profiles = {..._profiles, symbol: result.profile};
      return result.profile.country;
    } catch (e) {
      debugLog('[DepotAllocationState] Constituent failed for $symbol: $e');
      return null;
    } finally {
      _pending.remove(symbol);
    }
  }

  void reduceCache() {
    _generation++;
    _isFetching = false;
    _pending.clear();
    _profiles = const {};
    _cacheLoad = null;
    _cacheLoaded = false;
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'depot_market_search.dart';
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
    Future<List<String>> Function(DepotHolding holding)? confirmedSymbolsLoader,
    DateTime Function()? clock,
  }) : _profileLoader = profileLoader ?? _loadProfile,
       _sessionLoader = sessionLoader ?? YahooFinanceApi.session,
       _confirmedSymbolsLoader =
           confirmedSymbolsLoader ?? DepotMarketSearch.holdingSymbols,
       _clock = clock ?? DateTime.now;

  static const Duration retryAfter = Duration(days: 1);
  static const int _parallelRequests = 3;
  static const int _maxConstituents = 10;
  static const int _maxAlternateListings = 3;

  final DepotStore _store = DepotStore.instance;
  final Future<YahooAssetProfile?> Function(String, YahooSession?)
  _profileLoader;
  final Future<YahooSession?> Function() _sessionLoader;
  final Future<List<String>> Function(DepotHolding) _confirmedSymbolsLoader;
  final DateTime Function() _clock;

  Map<String, DepotAssetProfile> _profiles = const {};
  Map<String, DateTime> _attempts = {};
  final Set<String> _pending = {};
  Future<void>? _cacheLoad;
  bool _cacheLoaded = false;
  bool _isFetching = false;
  Completer<void>? _fetchDone;
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

  Future<void> ensureProfiles(Iterable<DepotHolding> holdings) async {
    if (_disposed) return;
    await ensureLoaded();
    if (_disposed || _isFetching) return;

    final generation = _generation;
    final targets = <String, DepotHolding>{};
    for (final holding in holdings) {
      if (holding.isSold ||
          holding.currentValue <= 0 ||
          holding.assetType != DepotAssetType.security) {
        continue;
      }
      final key = _keyOf(holding);
      if (key == null || _pending.contains(key)) continue;
      final cached = _profiles[key];
      if (!_needsProfile(holding, cached) || !_isDue(key, cached)) continue;
      targets[key] = holding;
    }
    if (targets.isEmpty) return;

    _isFetching = true;
    final done = _fetchDone = Completer<void>();
    _notify();
    var changed = false;
    try {
      final session = await _sessionLoader();
      final entries = targets.entries.toList();
      for (var start = 0; start < entries.length; start += _parallelRequests) {
        if (_disposed || generation != _generation) break;
        final chunk = entries.skip(start).take(_parallelRequests).toList();
        for (final entry in chunk) {
          _attempts[entry.key] = _clock();
        }
        await _store.saveAssetProfileAttempts(_attempts);
        final results = await Future.wait([
          for (final entry in chunk)
            _fetch(entry.key, entry.value, session, generation),
        ]);
        changed = results.any((fetched) => fetched) || changed;
      }
    } catch (e) {
      errorLog('[DepotAllocationState] Fetching profiles failed: $e');
    } finally {
      if (!_disposed && generation == _generation) {
        try {
          if (changed) await _store.saveAssetProfiles(_profiles);
          await _store.saveAssetProfileAttempts(_attempts);
        } catch (e) {
          errorLog('[DepotAllocationState] Saving profiles failed: $e');
        }
      }
      if (!_disposed && generation == _generation) {
        _isFetching = false;
        _notify();
      }
      if (identical(_fetchDone, done)) _fetchDone = null;
      done.complete();
    }
  }

  /// Fetches missing metadata, respecting the per-asset retry interval.
  Future<void> refresh(Iterable<DepotHolding> holdings) async {
    await _fetchDone?.future;
    await ensureProfiles(holdings);
  }

  Future<void> ensureLoaded() => _cacheLoad ??= _loadCache();

  bool _isDue(String key, DepotAssetProfile? cached) {
    final last =
        _attempts[key] ??
        (cached != null && cached.cacheVersion >= 3 ? cached.fetchedAt : null);
    return last == null || _clock().difference(last) >= retryAfter;
  }

  bool _needsProfile(DepotHolding holding, DepotAssetProfile? profile) {
    if (profile == null) return true;
    return switch (holding.kind) {
      DepotHoldingKind.etf || DepotHoldingKind.fund =>
        profile.sectorShares.isEmpty || profile.countryShares.isEmpty,
      DepotHoldingKind.stock =>
        profile.sector == null ||
            profile.industry == null ||
            (profile.country == null && profile.region == null),
      _ => false,
    };
  }

  Future<void> _loadCache() async {
    try {
      final cached = await _store.assetProfiles();
      final attempts = await _store.assetProfileAttempts();
      if (_disposed) return;
      _profiles = {...cached, ..._profiles};
      _attempts = {...attempts, ..._attempts};
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
      var profile = result?.profile;
      if (holding.kind == DepotHoldingKind.stock &&
          (profile?.country == null && profile?.region == null ||
              profile?.sector == null ||
              profile?.industry == null)) {
        profile = await _completeFromListings(
          holding,
          profile,
          session,
          generation,
        );
      }
      if (_disposed || generation != _generation) return false;
      if (profile == null) {
        return false;
      }
      if (profile.countryShares.isEmpty &&
          (result?.topHoldings.isNotEmpty ?? false)) {
        final shares = await _countryShares(
          result!.topHoldings,
          session,
          generation,
        );
        profile = profile.copyWith(countryShares: shares);
      }
      if (_disposed || generation != _generation) return false;
      final previous = _profiles[key];
      if (previous != null) {
        profile = DepotAssetProfile(
          sector: previous.sector ?? profile.sector,
          industry: previous.industry ?? profile.industry,
          country: previous.country ?? profile.country,
          region: previous.region ?? profile.region,
          sectorShares:
              previous.cacheVersion >= 3 && previous.sectorShares.isNotEmpty
              ? previous.sectorShares
              : profile.sectorShares,
          countryShares:
              previous.cacheVersion >= 3 && previous.countryShares.isNotEmpty
              ? previous.countryShares
              : profile.countryShares,
          fetchedAt: profile.fetchedAt,
        );
      }
      _profiles = {..._profiles, key: profile};
      return true;
    } catch (e) {
      errorLog('[DepotAllocationState] Profile failed for $key: $e');
      return false;
    } finally {
      _pending.remove(key);
    }
  }

  Future<DepotAssetProfile?> _completeFromListings(
    DepotHolding holding,
    DepotAssetProfile? profile,
    YahooSession? session,
    int generation,
  ) async {
    try {
      final symbols = await _confirmedSymbolsLoader(holding);
      final candidates = symbols
          .toSet()
          .where((symbol) => RegExp(r'^[A-Za-z0-9-]+$').hasMatch(symbol))
          .take(_maxAlternateListings);
      for (final symbol in candidates) {
        if (_disposed || generation != _generation) break;
        try {
          var alternate = _profiles[symbol];
          if ((alternate == null ||
                  (alternate.country == null && alternate.region == null)) &&
              _isDue(symbol, alternate)) {
            _attempts[symbol] = _clock();
            alternate =
                (await _profileLoader(symbol, session))?.profile ?? alternate;
            if (alternate != null) {
              _profiles = {..._profiles, symbol: alternate};
            }
          }
          if (alternate == null) continue;
          profile = DepotAssetProfile(
            sector: profile?.sector ?? alternate.sector,
            industry: profile?.industry ?? alternate.industry,
            country: profile?.country ?? alternate.country,
            region: profile?.region ?? alternate.region,
            sectorShares: profile?.sectorShares ?? const {},
            countryShares: profile?.countryShares ?? const {},
            fetchedAt: profile?.fetchedAt ?? alternate.fetchedAt,
          );
          if ((profile.country != null || profile.region != null) &&
              profile.sector != null &&
              profile.industry != null) {
            break;
          }
        } catch (e) {
          debugLog('[DepotAllocationState] Alternate listing failed: $e');
        }
      }
    } catch (e) {
      debugLog('[DepotAllocationState] Confirmed listings unavailable: $e');
    }
    return profile;
  }

  /// A fund's region mix is approximated from the domicile of its largest
  /// constituents, because Yahoo does not publish fund country weights.
  Future<Map<String, double>> _countryShares(
    List<({String symbol, double weight})> topHoldings,
    YahooSession? session,
    int generation,
  ) async {
    final countries = <String, double>{};
    final valid =
        topHoldings
            .where(
              (entry) =>
                  entry.weight.isFinite &&
                  entry.weight > 0 &&
                  entry.weight <= 1,
            )
            .toList()
          ..sort((a, b) => b.weight.compareTo(a.weight));
    final entries = valid.take(_maxConstituents).toList();
    if (entries.fold<double>(0, (sum, entry) => sum + entry.weight) > 1.001) {
      return const {};
    }
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
      }
    }
    return countries;
  }

  Future<String?> _constituentCountry(
    String symbol,
    YahooSession? session,
  ) async {
    final cached = _profiles[symbol];
    if (cached?.country != null || cached?.region != null) {
      return cached?.country ?? cached?.region;
    }
    if (!_isDue(symbol, cached) || !_pending.add(symbol)) return null;
    _attempts[symbol] = _clock();
    try {
      final result = await _profileLoader(symbol, session);
      if (result == null || _disposed) return null;
      _profiles = {..._profiles, symbol: result.profile};
      return result.profile.country ?? result.profile.region;
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
    _attempts = {};
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

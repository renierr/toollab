import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'depot_market_search.dart';
import 'market_data/onvista_api.dart';
import 'market_data/yahoo_finance_api.dart';
import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';

/// Sector, industry, region and fund holdings per position, fetched once from
/// onvista and Yahoo and cached in the tool database.
class DepotAllocationState extends ChangeNotifier {
  DepotAllocationState({
    Future<YahooAssetProfile?> Function(String query, YahooSession? session)?
    profileLoader,
    Future<YahooSession?> Function()? sessionLoader,
    Future<List<String>> Function(DepotHolding holding)? confirmedSymbolsLoader,
    Future<OnvistaFundBreakdown?> Function(String isin)? fundLoader,
    Future<String?> Function(String isin)? stockCountryLoader,
    DateTime Function()? clock,
  }) : _profileLoader = profileLoader ?? _loadProfile,
       _sessionLoader = sessionLoader ?? YahooFinanceApi.session,
       _confirmedSymbolsLoader =
           confirmedSymbolsLoader ?? DepotMarketSearch.holdingSymbols,
       _fundLoader = fundLoader ?? OnvistaApi.fundBreakdown,
       _stockCountryLoader = stockCountryLoader ?? OnvistaApi.stockCountry,
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
  final Future<OnvistaFundBreakdown?> Function(String) _fundLoader;
  final Future<String?> Function(String) _stockCountryLoader;
  final DateTime Function() _clock;

  Map<String, DepotAssetProfile> _profiles = const {};
  Map<String, DateTime> _attempts = {};
  final Set<String> _pending = {};
  final Set<String> _unsavedProfiles = {};
  final Set<String> _unsavedAttempts = {};
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

  /// The reported instrument type wins over the name heuristic, which files
  /// every security without "ETF" or "Fonds" in its name as a stock.
  DepotHoldingKind kindOf(DepotHolding holding) {
    if (holding.assetType != DepotAssetType.security) return holding.kind;
    return profileOf(holding)?.kind ?? holding.kind;
  }

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

  static bool _isFund(DepotHoldingKind kind) =>
      kind == DepotHoldingKind.etf || kind == DepotHoldingKind.fund;

  /// Fetches only positions whose metadata is missing or incomplete, at most
  /// once per [retryAfter]. With [force], every position is fetched again.
  Future<void> ensureProfiles(
    Iterable<DepotHolding> holdings, {
    bool force = false,
  }) async {
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
      if (!force && (!_needsProfile(holding, cached) || !_isDue(key, cached))) {
        continue;
      }
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
          _markAttempt(entry.key);
        }
        await _persist();
        final results = await Future.wait([
          for (final entry in chunk)
            _fetch(
              entry.key,
              entry.value,
              session,
              generation,
              replaceKnown: force,
            ),
        ]);
        changed = results.any((fetched) => fetched) || changed;
        if (changed) _notify();
      }
    } catch (e) {
      errorLog('[DepotAllocationState] Fetching profiles failed: $e');
    } finally {
      if (!_disposed && generation == _generation) {
        try {
          await _persist();
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

  /// Fetches every position again; cached values stay until replaced.
  Future<void> reloadAll(Iterable<DepotHolding> holdings) async {
    await _fetchDone?.future;
    await ensureProfiles(holdings, force: true);
  }

  Future<void> ensureLoaded() => _cacheLoad ??= _loadCache();

  void _setProfile(String key, DepotAssetProfile profile) {
    _profiles = {..._profiles, key: profile};
    _unsavedProfiles.add(key);
  }

  void _markAttempt(String key) {
    _attempts[key] = _clock();
    _unsavedAttempts.add(key);
  }

  /// Writes only the entries changed since the last save.
  Future<void> _persist() async {
    final profiles = {for (final key in _unsavedProfiles) key: ?_profiles[key]};
    final attempts = {for (final key in _unsavedAttempts) key: ?_attempts[key]};
    _unsavedProfiles.clear();
    _unsavedAttempts.clear();
    await _store.saveAssetProfiles(profiles);
    await _store.saveAssetProfileAttempts(attempts);
  }

  bool _isDue(String key, DepotAssetProfile? cached) {
    final last =
        _attempts[key] ??
        (cached != null &&
                cached.cacheVersion >= DepotAssetProfile.currentVersion
            ? cached.fetchedAt
            : null);
    return last == null || _clock().difference(last) >= retryAfter;
  }

  bool _needsProfile(DepotHolding holding, DepotAssetProfile? profile) {
    if (profile == null) return true;
    final kind = profile.kind ?? holding.kind;
    if (_isFund(kind)) {
      return profile.cacheVersion < DepotAssetProfile.currentVersion ||
          (profile.sectorShares.isEmpty && profile.countryShares.isEmpty);
    }
    if (kind == DepotHoldingKind.stock) {
      return profile.sector == null ||
          (profile.country == null && profile.region == null);
    }
    return false;
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
    int generation, {
    required bool replaceKnown,
  }) async {
    if (!_pending.add(key)) return false;
    bool stale() => _disposed || generation != _generation;
    try {
      final isin = holding.isin?.trim();
      var kind = holding.kind;
      OnvistaFundBreakdown? fund;
      if (_isFund(kind) && isin != null && isin.isNotEmpty) {
        fund = await _fundLoader(isin);
      }
      if (stale()) return false;

      // A complete onvista split makes the Yahoo round trips unnecessary.
      DepotAssetProfile? profile;
      var topHoldings = const <({String symbol, double weight})>[];
      if (fund == null ||
          fund.countryShares.isEmpty ||
          fund.sectorShares.isEmpty) {
        final result = await _profileLoader(key, session);
        if (stale()) return false;
        profile = result?.profile;
        topHoldings = result?.topHoldings ?? const [];
        final reported = profile?.kind;
        if (reported != null) kind = reported;
        if (fund == null &&
            _isFund(kind) &&
            !_isFund(holding.kind) &&
            isin != null &&
            isin.isNotEmpty) {
          fund = await _fundLoader(isin);
          if (stale()) return false;
        }
      }

      if (kind == DepotHoldingKind.stock) {
        profile = await _completeStock(holding, profile, session, generation);
      } else if (_isFund(kind)) {
        profile = await _completeFund(
          profile ?? DepotAssetProfile(fetchedAt: _clock()),
          fund,
          topHoldings,
          session,
          generation,
        );
      }
      if (stale() || profile == null || profile.isEmpty) return false;
      profile = profile.copyWith(kind: kind);

      final previous = _profiles[key];
      if (previous != null) {
        final current =
            previous.cacheVersion >= DepotAssetProfile.currentVersion;
        // Retries keep what is known; only a full reload replaces it.
        final (first, second) = replaceKnown
            ? (profile, previous)
            : (previous, profile);
        profile = DepotAssetProfile(
          sector: first.sector ?? second.sector,
          industry: first.industry ?? second.industry,
          country: first.country ?? second.country,
          region: first.region ?? second.region,
          kind: profile.kind,
          sectorShares: profile.sectorShares.isNotEmpty || !current
              ? profile.sectorShares
              : previous.sectorShares,
          countryShares: profile.countryShares.isNotEmpty || !current
              ? profile.countryShares
              : previous.countryShares,
          constituents: profile.constituents.isNotEmpty || !current
              ? profile.constituents
              : previous.constituents,
          fetchedAt: profile.fetchedAt,
        );
      }
      _setProfile(key, profile);
      return true;
    } catch (e) {
      errorLog('[DepotAllocationState] Profile failed for $key: $e');
      return false;
    } finally {
      _pending.remove(key);
    }
  }

  Future<DepotAssetProfile?> _completeStock(
    DepotHolding holding,
    DepotAssetProfile? profile,
    YahooSession? session,
    int generation,
  ) async {
    final isin = holding.isin?.trim();
    if (profile?.country == null &&
        profile?.region == null &&
        isin != null &&
        isin.isNotEmpty) {
      final country = await _stockCountryLoader(isin);
      if (country != null) {
        profile = (profile ?? DepotAssetProfile(fetchedAt: _clock())).copyWith(
          country: country,
        );
      }
    }
    if (_disposed || generation != _generation) return profile;
    if (profile?.country == null && profile?.region == null ||
        profile?.sector == null ||
        profile?.industry == null) {
      profile = await _completeFromListings(
        holding,
        profile,
        session,
        generation,
      );
    }
    return profile;
  }

  Future<DepotAssetProfile> _completeFund(
    DepotAssetProfile profile,
    OnvistaFundBreakdown? fund,
    List<({String symbol, double weight})> topHoldings,
    YahooSession? session,
    int generation,
  ) async {
    if (fund != null) {
      profile = profile.copyWith(
        sectorShares: fund.sectorShares.isNotEmpty ? fund.sectorShares : null,
        countryShares: fund.countryShares.isNotEmpty
            ? fund.countryShares
            : null,
        constituents: fund.constituents.isNotEmpty ? fund.constituents : null,
      );
    }
    if (profile.countryShares.isEmpty && topHoldings.isNotEmpty) {
      final shares = await _countryShares(topHoldings, session, generation);
      profile = profile.copyWith(countryShares: shares);
    }
    return profile;
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
            _markAttempt(symbol);
            alternate =
                (await _profileLoader(symbol, session))?.profile ?? alternate;
            if (alternate != null) _setProfile(symbol, alternate);
          }
          if (alternate == null) continue;
          profile = DepotAssetProfile(
            sector: profile?.sector ?? alternate.sector,
            industry: profile?.industry ?? alternate.industry,
            country: profile?.country ?? alternate.country,
            region: profile?.region ?? alternate.region,
            kind: profile?.kind,
            sectorShares: profile?.sectorShares ?? const {},
            countryShares: profile?.countryShares ?? const {},
            constituents: profile?.constituents ?? const [],
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

  /// Fallback when onvista has no country split: approximate it from the
  /// domicile of the fund's largest constituents.
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
    _markAttempt(symbol);
    try {
      final result = await _profileLoader(symbol, session);
      if (result == null || _disposed) return null;
      _setProfile(symbol, result.profile);
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
    _unsavedProfiles.clear();
    _unsavedAttempts.clear();
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

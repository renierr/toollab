import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'depot_logo_downloader.dart';
import 'depot_market_search.dart';
import 'market_data/yahoo_finance_api.dart';
import 'models/depot_holding_logo.dart';
import 'models/depot_wishlist.dart';

/// Wishlist entries are independent of Parqet.
class DepotWishlistState extends ChangeNotifier {
  DepotWishlistState({
    Future<DepotWishlistQuote> Function(String)? quoteLoader,
    Future<List<DepotWishlistSearchResult>> Function(String)? searchLoader,
    Future<double> Function(String, String)? fxLoader,
    Future<Uint8List> Function(String)? logoLoader,
    Future<DepotWishlistQuote> Function(String)? historyLoader,
  }) : _quoteLoader = quoteLoader ?? YahooFinanceApi.intradayQuote,
       _searchLoader = searchLoader ?? DepotMarketSearch.search,
       _fxLoader = fxLoader ?? YahooFinanceApi.fxRate,
       _logoLoader = logoLoader ?? _downloadLogo,
       _historyLoader = historyLoader ?? YahooFinanceApi.yearDailyQuote {
    _wishlistSubscription = _store.wishlistChanges.listen((_) {
      unawaited(_reloadWishlist());
    });
  }

  static const _parallelRequests = 4;
  static const _maxHistoryEntries = 16;
  static const _searchDebounce = Duration(milliseconds: 350);

  final DepotStore _store = DepotStore.instance;
  late final StreamSubscription<void> _wishlistSubscription;
  final Future<DepotWishlistQuote> Function(String) _quoteLoader;
  final Future<List<DepotWishlistSearchResult>> Function(String) _searchLoader;
  final Future<double> Function(String, String) _fxLoader;
  final Future<Uint8List> Function(String) _logoLoader;
  final Future<DepotWishlistQuote> Function(String) _historyLoader;

  Future<void>? _loading;
  bool _disposed = false;
  bool _isLoaded = false;
  bool _showEuro = true;
  Future<void> _settingsWrite = Future.value();
  bool _loadFailed = false;
  bool _isRefreshing = false;
  bool _refreshAfterSync = false;
  int _wishlistRevision = 0;
  bool _isSearching = false;
  bool _searchFailed = false;
  String _query = '';
  Timer? _debounce;
  Timer? _syncDebounce;
  Future<bool> Function()? _syncWishlist;
  int _searchToken = 0;
  int _cacheRevision = 0;
  bool _restoreLogos = false;
  bool _refreshOnResume = false;
  ({int revision, Future<void> future})? _restoringLogos;

  List<DepotWishlistItem> _items = const [];
  Map<String, DepotWishlistQuote> _quotes = const {};
  Set<String> _failed = const {};
  final Set<String> _pending = {};
  List<DepotWishlistSearchResult> _results = const [];
  final Map<String, double> _eurRates = {};
  final Map<String, Future<void>> _fxLoads = {};
  final Map<String, Uint8List> _logos = {};
  final Map<String, ({int revision, Future<void> future})> _logoLoads = {};
  final Map<String, Set<Future<void>>> _allLogoLoads = {};
  final Map<String, ({DepotWishlistQuote quote, DateTime fetchedAt})>
  _histories = {};
  final Map<String, ({int revision, Future<void> future})> _historyLoads = {};
  final Set<String> _historyFailed = {};

  static String logoUrl(String symbol) => Uri.https(
    'financialmodelingprep.com',
    '/image-stock/${Uri.encodeComponent(symbol)}.png',
  ).toString();

  static Future<Uint8List> _downloadLogo(String symbol) =>
      const DepotLogoDownloader().download(logoUrl(symbol));

  bool get isLoaded => _isLoaded;
  bool get showEuro => _showEuro;
  bool get loadFailed => _loadFailed;
  bool get isRefreshing => _isRefreshing;
  bool get isSearching => _isSearching;
  bool get searchFailed => _searchFailed;
  String get query => _query;
  List<DepotWishlistItem> get items => _items;
  List<DepotWishlistItem> get itemsByDayChange {
    final ranked = [
      for (final (index, item) in _items.indexed)
        (
          index: index,
          item: item,
          change: _quotes[item.symbol]?.dayChangePercent,
        ),
    ];
    ranked.sort((a, b) {
      final aChange = a.change;
      final bChange = b.change;
      final aValid = aChange != null && aChange.isFinite;
      final bValid = bChange != null && bChange.isFinite;
      if (aValid && bValid) {
        final comparison = bChange.compareTo(aChange);
        if (comparison != 0) return comparison;
      } else if (aValid != bValid) {
        return aValid ? -1 : 1;
      }
      return a.index.compareTo(b.index);
    });
    return [for (final entry in ranked) entry.item];
  }

  List<DepotWishlistSearchResult> get results => _results;

  /// Symbols whose last quote request failed, e.g. delisted or offline.
  Set<String> get failed => _failed;

  DepotWishlistQuote? quoteFor(String symbol) => _quotes[symbol];
  DepotWishlistQuote? historyFor(String symbol) => _histories[symbol]?.quote;
  bool isLoadingHistory(String symbol) => _historyLoads.containsKey(symbol);
  bool historyFailed(String symbol) => _historyFailed.contains(symbol);
  Uint8List? logoFor(String symbol) => _logos[symbol];
  double? euroRate(String currency) =>
      currency == 'EUR' ? 1 : _eurRates[currency];
  double? displayEuroRate(String currency) =>
      _showEuro ? euroRate(currency) : null;

  bool contains(String symbol) => _items.any((item) => item.symbol == symbol);
  bool canLinkIsin(DepotWishlistSearchResult result) =>
      result.isin != null &&
      _items.any((item) => item.symbol == result.symbol && item.isin == null);
  bool isAdding(String symbol) => _pending.contains(symbol);

  void setSyncCallback(Future<bool> Function()? callback) {
    _syncWishlist = callback;
    if (callback == null) _syncDebounce?.cancel();
  }

  void _scheduleSync() {
    if (_syncWishlist == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 1), () async {
      final sync = _syncWishlist;
      if (sync != null && !await sync() && identical(sync, _syncWishlist)) {
        _scheduleSync();
      }
    });
  }

  void requestSync() => _scheduleSync();

  Future<void> reloadFromStore() => _reloadWishlist();

  Future<void> ensureHistory(String symbol) {
    if (_disposed || !contains(symbol)) return Future.value();
    final cached = _histories[symbol];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(hours: 24)) {
      return Future.value();
    }
    final loading = _historyLoads[symbol];
    if (loading != null && loading.revision == _cacheRevision) {
      return loading.future;
    }
    _historyFailed.remove(symbol);
    final item = _items.firstWhere((item) => item.symbol == symbol);
    final revision = _cacheRevision;
    final future = _loadHistory(item, revision);
    _historyLoads[symbol] = (revision: revision, future: future);
    _notify();
    return future;
  }

  Future<void> _loadHistory(DepotWishlistItem item, int revision) async {
    final symbol = item.symbol;
    try {
      final quote = await _historyLoader(symbol);
      if (_disposed || revision != _cacheRevision || !_items.contains(item)) {
        return;
      }
      _histories.remove(symbol);
      _histories[symbol] = (quote: quote, fetchedAt: DateTime.now());
      while (_histories.length > _maxHistoryEntries) {
        _histories.remove(_histories.keys.first);
      }
    } catch (e) {
      if (!_disposed && revision == _cacheRevision && _items.contains(item)) {
        _historyFailed.add(symbol);
        debugLog('[DepotWishlistState] History unavailable for $symbol: $e');
      }
    } finally {
      if (_historyLoads[symbol]?.revision == revision) {
        _historyLoads.remove(symbol);
      }
      _notify();
    }
  }

  Future<void> setShowEuro(bool value) {
    if (_showEuro == value) return _settingsWrite;
    _showEuro = value;
    _notify();
    _settingsWrite = _settingsWrite.then((_) async {
      try {
        await _store.setWishlistEuroDisplay(value);
      } catch (e) {
        errorLog('[DepotWishlistState] Saving currency setting failed: $e');
      }
    });
    if (value) {
      unawaited(
        Future.wait(
          {for (final quote in _quotes.values) quote.currency}.map(_loadRate),
        ),
      );
    }
    return _settingsWrite;
  }

  Future<void> ensureLoaded() async {
    final revision = _cacheRevision;
    await (_loading ??= _load());
    if (_disposed || revision != _cacheRevision) return;
    if (_restoreLogos) {
      final restoring = _restoringLogos;
      if (restoring == null || restoring.revision != revision) {
        final future = _loadCachedLogos(revision);
        _restoringLogos = (revision: revision, future: future);
      }
      await _restoringLogos!.future;
      if (!_disposed && revision == _cacheRevision) {
        unawaited(_loadMissingLogos(_items));
      }
    }
    if (!_disposed && revision == _cacheRevision && _refreshOnResume) {
      _refreshOnResume = false;
      unawaited(refresh());
    }
  }

  Future<void> _loadCachedLogos(int revision) async {
    try {
      final logos = await _store.wishlistLogos();
      if (_disposed || revision != _cacheRevision) return;
      _logos.addEntries(
        logos
            .where((logo) => contains(logo.key))
            .map((logo) => MapEntry(logo.key, logo.bytes)),
      );
      _restoreLogos = false;
      _notify();
    } catch (e) {
      errorLog('[DepotWishlistState] Loading logos failed: $e');
    } finally {
      if (_restoringLogos?.revision == revision) _restoringLogos = null;
    }
  }

  Future<void> _load() async {
    final revision = _cacheRevision;
    try {
      _items = await _store.wishlistItems();
    } catch (e) {
      errorLog('[DepotWishlistState] Loading failed: $e');
      _loadFailed = true;
    }
    try {
      _showEuro = await _store.wishlistEuroDisplay();
    } catch (e) {
      errorLog('[DepotWishlistState] Loading currency setting failed: $e');
    }
    try {
      final logos = await _store.wishlistLogos();
      if (revision == _cacheRevision) {
        _logos.addEntries(logos.map((logo) => MapEntry(logo.key, logo.bytes)));
      }
    } catch (e) {
      errorLog('[DepotWishlistState] Loading logos failed: $e');
    }
    if (_disposed) return;
    _isLoaded = true;
    _notify();
    if (_items.isNotEmpty) {
      if (revision == _cacheRevision) {
        unawaited(refresh());
      } else {
        _refreshOnResume = true;
      }
    }
  }

  Future<void> _reloadWishlist() async {
    if (!_isLoaded) {
      if (_loading != null) await _loading;
      if (!_isLoaded || _disposed) return;
    }
    final revision = ++_wishlistRevision;
    try {
      final items = await _store.wishlistItems();
      if (_disposed) return;
      if (revision != _wishlistRevision) {
        unawaited(_reloadWishlist());
        return;
      }
      _items = items;
      final symbols = items.map((item) => item.symbol).toSet();
      _quotes = Map.fromEntries(
        _quotes.entries.where((e) => symbols.contains(e.key)),
      );
      _failed = _failed.where(symbols.contains).toSet();
      _logos.removeWhere((symbol, _) => !symbols.contains(symbol));
      _histories.removeWhere((symbol, _) => !symbols.contains(symbol));
      _historyFailed.removeWhere((symbol) => !symbols.contains(symbol));
      _notify();
      if (_isRefreshing) {
        _refreshAfterSync = true;
      } else {
        unawaited(refresh());
      }
    } catch (e) {
      errorLog('[DepotWishlistState] Reloading synced items failed: $e');
    }
  }

  Future<void> _loadMissingLogos(List<DepotWishlistItem> items) async {
    final revision = _cacheRevision;
    for (var start = 0; start < items.length; start += _parallelRequests) {
      if (_disposed || revision != _cacheRevision) return;
      await Future.wait(
        items.skip(start).take(_parallelRequests).map(_loadLogo),
      );
    }
  }

  Future<void> _loadLogo(DepotWishlistItem item) {
    if (_disposed ||
        !_items.contains(item) ||
        _logos.containsKey(item.symbol)) {
      return Future.value();
    }
    final revision = _cacheRevision;
    final loading = _logoLoads[item.symbol];
    if (loading != null && loading.revision == revision) return loading.future;
    final future = _fetchLogo(item, revision);
    _logoLoads[item.symbol] = (revision: revision, future: future);
    _allLogoLoads.putIfAbsent(item.symbol, () => {}).add(future);
    unawaited(
      future.then((_) {
        final loads = _allLogoLoads[item.symbol];
        loads?.remove(future);
        if (loads?.isEmpty ?? false) _allLogoLoads.remove(item.symbol);
      }),
    );
    return future;
  }

  Future<void> _fetchLogo(DepotWishlistItem item, int revision) async {
    try {
      final bytes = await _logoLoader(item.symbol);
      if (_disposed || revision != _cacheRevision || !_items.contains(item)) {
        return;
      }
      await _store.saveWishlistLogo(
        DepotHoldingLogo(
          key: item.symbol,
          sourceUrl: logoUrl(item.symbol),
          bytes: bytes,
          fetchedAt: DateTime.now(),
        ),
      );
      if (_disposed || revision != _cacheRevision || !_items.contains(item)) {
        return;
      }
      _logos[item.symbol] = bytes;
      _notify();
    } catch (e) {
      debugLog('[DepotWishlistState] Logo unavailable for ${item.symbol}: $e');
    } finally {
      if (_logoLoads[item.symbol]?.revision == revision) {
        _logoLoads.remove(item.symbol);
      }
    }
  }

  Future<void> _loadRate(String currency) {
    if (currency.isEmpty || currency == 'EUR' || _disposed) {
      return Future.value();
    }
    return _fxLoads.putIfAbsent(currency, () async {
      try {
        final rate = await _fxLoader(currency, 'EUR');
        if (_disposed) return;
        if (!rate.isFinite || rate <= 0) {
          throw const FormatException('Invalid FX rate');
        }
        _eurRates[currency] = rate;
      } catch (e) {
        _eurRates.remove(currency);
        debugLog('[DepotWishlistState] EUR rate unavailable for $currency: $e');
      } finally {
        _fxLoads.remove(currency);
        _notify();
      }
    });
  }

  /// Re-reads every quote. Pull-to-refresh calls this.
  Future<void> refresh() async {
    if (_isRefreshing || _disposed) return;
    _isRefreshing = true;
    final revision = _cacheRevision;
    _notify();
    unawaited(_loadMissingLogos(_items));

    final snapshot = {for (final item in _items) item.symbol: item};
    final symbols = snapshot.keys.toList();
    final quotes = <String, DepotWishlistQuote>{};
    final failed = <String>{};
    for (var start = 0; start < symbols.length; start += _parallelRequests) {
      final chunk = symbols.skip(start).take(_parallelRequests);
      final loaded = await Future.wait(
        chunk.map((symbol) async {
          try {
            final quote = await _quoteLoader(symbol);
            return (symbol: symbol, quote: quote);
          } catch (e) {
            errorLog('[DepotWishlistState] Quote failed for $symbol: $e');
            return (symbol: symbol, quote: null);
          }
        }),
      );
      for (final entry in loaded) {
        final quote = entry.quote;
        if (quote == null) {
          failed.add(entry.symbol);
        } else {
          quotes[entry.symbol] = quote;
        }
      }
    }

    if (_disposed) return;
    final current = {for (final item in _items) item.symbol: item};
    bool unchanged(String symbol) =>
        identical(current[symbol], snapshot[symbol]);
    _quotes = {
      ..._quotes,
      for (final entry in quotes.entries)
        if (unchanged(entry.key))
          entry.key: revision == _cacheRevision
              ? entry.value
              : entry.value.withReducedPoints(),
    };
    _failed = {
      ..._failed.where((symbol) => !snapshot.containsKey(symbol)),
      ...failed.where(unchanged),
    };
    if (_showEuro) {
      await Future.wait(
        {for (final quote in quotes.values) quote.currency}.map(_loadRate),
      );
    }
    if (_disposed) return;
    _isRefreshing = false;
    _notify();
    if (_refreshAfterSync) {
      _refreshAfterSync = false;
      unawaited(refresh());
    }
  }

  void search(String value) {
    _query = value;
    _debounce?.cancel();
    final token = ++_searchToken;
    final query = value.trim();
    if (query.length < 2) {
      _isSearching = false;
      _searchFailed = false;
      _results = const [];
      _notify();
      return;
    }
    _isSearching = true;
    _searchFailed = false;
    _notify();
    _debounce = Timer(_searchDebounce, () => _runSearch(query, token));
  }

  Future<void> _runSearch(String query, int token) async {
    try {
      final results = await _searchLoader(query);
      if (_disposed || token != _searchToken) return;
      _results = results;
      _isSearching = false;
      _notify();
    } catch (e) {
      if (_disposed || token != _searchToken) return;
      errorLog('[DepotWishlistState] Search failed for "$query": $e');
      _results = const [];
      _isSearching = false;
      _searchFailed = true;
      _notify();
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _searchToken++;
    _query = '';
    _isSearching = false;
    _searchFailed = false;
    _results = const [];
    _notify();
  }

  /// Resolves the current quote first, because the currency comes from it.
  /// Returns false when the security could not be resolved.
  Future<bool> add(DepotWishlistSearchResult result) async {
    await ensureLoaded();
    if (_disposed || _loadFailed) return false;
    if (contains(result.symbol) && !canLinkIsin(result)) return true;
    if (!_pending.add(result.symbol)) return false;
    _notify();
    try {
      return await _add(result);
    } finally {
      _pending.remove(result.symbol);
      _notify();
    }
  }

  Future<bool> _add(DepotWishlistSearchResult result) async {
    final revision = _cacheRevision;
    if (canLinkIsin(result)) {
      final old = _items.firstWhere((item) => item.symbol == result.symbol);
      final updated = old.withIsin(result.isin!);
      try {
        await _store.saveWishlistItem(updated);
        _wishlistRevision++;
      } catch (e) {
        errorLog('[DepotWishlistState] Saving ISIN failed: $e');
        return false;
      }
      if (!_disposed) {
        _items = [
          for (final item in _items) identical(item, old) ? updated : item,
        ];
        _notify();
        _scheduleSync();
        unawaited(() async {
          await _logoLoads[result.symbol]?.future;
          if (!_disposed && revision == _cacheRevision) {
            await _loadLogo(updated);
          }
        }());
      }
      return true;
    }
    final DepotWishlistQuote quote;
    try {
      quote = await _quoteLoader(result.symbol);
    } catch (e) {
      errorLog('[DepotWishlistState] Add failed for ${result.symbol}: $e');
      return false;
    }
    final item = DepotWishlistItem(
      symbol: result.symbol,
      name: result.name,
      quoteType: result.quoteType,
      exchange: result.exchange.isEmpty ? quote.exchange : result.exchange,
      currency: quote.currency,
      addedPrice: quote.price,
      addedAt: DateTime.now(),
      isin: result.isin,
    );
    try {
      await _store.saveWishlistItem(item);
      _wishlistRevision++;
    } catch (e) {
      errorLog('[DepotWishlistState] Saving ${item.symbol} failed: $e');
      return false;
    }
    if (_disposed) return true;
    _items = [item, ..._items.where((i) => i.symbol != item.symbol)];
    _quotes = {
      ..._quotes,
      item.symbol: revision == _cacheRevision
          ? quote
          : quote.withReducedPoints(),
    };
    _failed = {..._failed}..remove(item.symbol);
    _notify();
    _scheduleSync();
    if (revision == _cacheRevision) {
      if (_showEuro) unawaited(_loadRate(quote.currency));
      unawaited(_loadLogo(item));
    }
    return true;
  }

  Future<bool> remove(String symbol) async {
    try {
      await _store.deleteWishlistItem(symbol);
      _wishlistRevision++;
    } catch (e) {
      errorLog('[DepotWishlistState] Deleting $symbol failed: $e');
      return false;
    }
    if (_disposed) return true;
    _items = [
      for (final item in _items)
        if (item.symbol != symbol) item,
    ];
    _quotes = {..._quotes}..remove(symbol);
    _histories.remove(symbol);
    _historyFailed.remove(symbol);
    _failed = {..._failed}..remove(symbol);
    _logos.remove(symbol);
    _notify();
    _scheduleSync();
    await Future.wait(_allLogoLoads[symbol]?.toList() ?? const []);
    final current = _items.where((item) => item.symbol == symbol).firstOrNull;
    if (current != null) {
      unawaited(_loadLogo(current));
    } else {
      try {
        await _store.deleteWishlistLogo(symbol);
      } catch (e) {
        errorLog('[DepotWishlistState] Deleting logo failed: $e');
      }
    }
    return true;
  }

  void reduceCache() {
    if (_disposed) return;
    _cacheRevision++;
    _quotes = {
      for (final entry in _quotes.entries)
        entry.key: entry.value.withReducedPoints(),
    };
    _histories.clear();
    _historyLoads.clear();
    _historyFailed.clear();
    _logos.clear();
    _logoLoads.clear();
    _restoreLogos = true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _syncDebounce?.cancel();
    unawaited(_wishlistSubscription.cancel());
    super.dispose();
  }
}

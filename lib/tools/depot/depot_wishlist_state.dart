import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'dividends/yahoo_finance_api.dart';
import 'models/depot_wishlist.dart';

/// Local-only watchlist. Nothing here is written to Parqet, so a sync and a
/// disconnect leave it untouched.
class DepotWishlistState extends ChangeNotifier {
  DepotWishlistState({
    Future<DepotWishlistQuote> Function(String)? quoteLoader,
    Future<List<DepotWishlistSearchResult>> Function(String)? searchLoader,
  }) : _quoteLoader = quoteLoader ?? YahooFinanceApi.wishlistQuote,
       _searchLoader = searchLoader ?? YahooFinanceApi.searchWishlist;

  static const _parallelRequests = 4;
  static const _searchDebounce = Duration(milliseconds: 350);

  final DepotStore _store = DepotStore.instance;
  final Future<DepotWishlistQuote> Function(String) _quoteLoader;
  final Future<List<DepotWishlistSearchResult>> Function(String) _searchLoader;

  Future<void>? _loading;
  bool _disposed = false;
  bool _isLoaded = false;
  bool _loadFailed = false;
  bool _isRefreshing = false;
  bool _isSearching = false;
  bool _searchFailed = false;
  String _query = '';
  Timer? _debounce;
  int _searchToken = 0;

  List<DepotWishlistItem> _items = const [];
  Map<String, DepotWishlistQuote> _quotes = const {};
  Set<String> _failed = const {};
  final Set<String> _pending = {};
  List<DepotWishlistSearchResult> _results = const [];

  bool get isLoaded => _isLoaded;
  bool get loadFailed => _loadFailed;
  bool get isRefreshing => _isRefreshing;
  bool get isSearching => _isSearching;
  bool get searchFailed => _searchFailed;
  String get query => _query;
  List<DepotWishlistItem> get items => _items;
  List<DepotWishlistSearchResult> get results => _results;

  /// Symbols whose last quote request failed, e.g. delisted or offline.
  Set<String> get failed => _failed;

  DepotWishlistQuote? quoteFor(String symbol) => _quotes[symbol];

  bool contains(String symbol) => _items.any((item) => item.symbol == symbol);
  bool isAdding(String symbol) => _pending.contains(symbol);

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      _items = await _store.wishlistItems();
    } catch (e) {
      errorLog('[DepotWishlistState] Loading failed: $e');
      _loadFailed = true;
    }
    if (_disposed) return;
    _isLoaded = true;
    _notify();
    if (_items.isNotEmpty) unawaited(refresh());
  }

  /// Re-reads every quote. Pull-to-refresh calls this.
  Future<void> refresh() async {
    if (_isRefreshing || _disposed) return;
    _isRefreshing = true;
    _notify();

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
        if (unchanged(entry.key)) entry.key: entry.value,
    };
    _failed = {
      ..._failed.where((symbol) => !snapshot.containsKey(symbol)),
      ...failed.where(unchanged),
    };
    _isRefreshing = false;
    _notify();
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
    if (contains(result.symbol)) return true;
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
    );
    try {
      await _store.saveWishlistItem(item);
    } catch (e) {
      errorLog('[DepotWishlistState] Saving ${item.symbol} failed: $e');
      return false;
    }
    if (_disposed) return true;
    _items = [item, ..._items.where((i) => i.symbol != item.symbol)];
    _quotes = {..._quotes, item.symbol: quote};
    _failed = {..._failed}..remove(item.symbol);
    _notify();
    return true;
  }

  Future<bool> remove(String symbol) async {
    try {
      await _store.deleteWishlistItem(symbol);
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
    _failed = {..._failed}..remove(symbol);
    _notify();
    return true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}

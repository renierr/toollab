import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/trimz_catalog.dart';
import 'models/trimz_saved_series.dart';
import 'models/trimz_series.dart';
import 'models/trimz_series_detail.dart';
import 'trimz_api.dart';
import 'trimz_db_helper.dart';

class TrimzState extends ChangeNotifier {
  static const String _adaptiveKey = 'adaptive_stream';
  static const String _autoplayKey = 'autoplay_next';
  static const String _translatedKey = 'translated_titles';

  final TrimzApi _api;
  final TrimzDbHelper _db;

  TrimzState({this._api = const TrimzApi(), TrimzDbHelper? db})
    : _db = db ?? TrimzDbHelper.instance;

  bool _initialized = false;
  String _appLanguage = 'en';

  bool _adaptiveStream = true;
  bool _autoplayNext = true;
  bool _translatedTitles = true;

  List<TrimzGenre> _genres = const [];
  String? _genre;
  List<TrimzSection> _sections = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _failed = false;
  int _generation = 0;

  Map<String, TrimzSavedSeries> _saved = const {};
  final Map<String, TrimzSeriesDetail> _details = {};

  String _query = '';
  List<TrimzSeries> _results = const [];
  int? _resultsNext;
  bool _searching = false;
  bool _searchFailed = false;
  int _searchGeneration = 0;

  bool get adaptiveStream => _adaptiveStream;
  bool get autoplayNext => _autoplayNext;
  bool get translatedTitles => _translatedTitles;

  List<TrimzGenre> get genres => _genres;
  String? get genre => _genre;
  List<TrimzSection> get sections => _sections;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get failed => _failed;

  String get query => _query;
  List<TrimzSeries> get results => _results;
  bool get searching => _searching;
  bool get searchFailed => _searchFailed;
  bool get resultsHaveMore => _resultsNext != null;

  String get _locale => _translatedTitles ? _appLanguage : 'en';

  List<TrimzSavedSeries> get continueWatching =>
      _saved.values.where((s) => s.watched).toList()
        ..sort((a, b) => b.watchedAt!.compareTo(a.watchedAt!));

  List<TrimzSavedSeries> get myList =>
      _saved.values.where((s) => s.onList).toList()
        ..sort((a, b) => b.savedAt!.compareTo(a.savedAt!));

  TrimzSavedSeries? savedFor(String id) => _saved[id];

  /// Catalog titles follow the app language when [translatedTitles] is on.
  void setAppLanguage(String language) {
    if (language == _appLanguage) return;
    _appLanguage = language;
    final loaded = _sections.isNotEmpty || _loading;
    if (_initialized && _translatedTitles && loaded) unawaited(refresh());
  }

  Future<void> init() async {
    if (_initialized) {
      if (_sections.isEmpty && !_loading) await refresh();
      return;
    }
    _initialized = true;
    await _loadSettings();
    await _loadSaved();
    await refresh();
  }

  /// Frees the catalog after the tool closes; history and list stay stored.
  void release() {
    _initialized = false;
    _generation++;
    _searchGeneration++;
    _genres = const [];
    _sections = const [];
    _details.clear();
    _saved = const {};
    _results = const [];
    _query = '';
    _resultsNext = null;
    _genre = null;
    _loading = false;
    _loadingMore = false;
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    final id = TrimzTool.config.id;
    try {
      _adaptiveStream = await db.getSetting(id, _adaptiveKey) != 'false';
      _autoplayNext = await db.getSetting(id, _autoplayKey) != 'false';
      _translatedTitles = await db.getSetting(id, _translatedKey) != 'false';
    } catch (e) {
      errorLog('[TrimzState] Loading settings failed: $e');
    }
  }

  Future<void> _loadSaved() async {
    try {
      _saved = {for (final s in await _db.all()) s.id: s};
      notifyListeners();
    } catch (e) {
      errorLog('[TrimzState] Loading history failed: $e');
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _loadingMore = false;
    _failed = false;
    notifyListeners();
    try {
      final genre = _genre;
      final explore = _api.explore(locale: _locale, genre: genre);
      if (_genres.isEmpty || genre == null) {
        _genres = await _api.genres(locale: _locale).catchError((Object e) {
          debugLog('[TrimzState] Genres failed: $e');
          return _genres;
        });
      }
      final sections = (await explore).sections;
      if (generation != _generation) return;
      _sections = sections;
      _details.clear();
    } catch (e) {
      debugLog('[TrimzState] Explore failed: $e');
      if (generation != _generation) return;
      _failed = true;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> selectGenre(String? genre) async {
    if (genre == _genre) return;
    _genre = genre;
    _sections = const [];
    await refresh();
  }

  /// Loads the next page of the last section that has one.
  Future<void> loadMore() async {
    if (_loading || _loadingMore) return;
    final index = _sections.lastIndexWhere((s) => s.hasMore);
    if (index < 0) return;
    final section = _sections[index];
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _api.moreOf(
        section.id,
        offset: section.nextOffset!,
        locale: _locale,
        genre: _genre,
      );
      if (generation != _generation) return;
      _sections = [
        for (final s in _sections)
          identical(s, section) ? s.appended(page.items, page.nextOffset) : s,
      ];
    } catch (e) {
      debugLog('[TrimzState] Loading more failed: $e');
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    final generation = ++_searchGeneration;
    _query = trimmed;
    _results = const [];
    _resultsNext = null;
    _searchFailed = false;
    _searching = trimmed.isNotEmpty;
    notifyListeners();
    if (trimmed.isEmpty) return;
    await _searchPage(trimmed, 0, generation);
  }

  Future<void> searchMore() async {
    final next = _resultsNext;
    if (_searching || next == null || _query.isEmpty) return;
    _searching = true;
    notifyListeners();
    await _searchPage(_query, next, _searchGeneration);
  }

  Future<void> _searchPage(String query, int offset, int generation) async {
    try {
      final page = await _api.search(query, offset: offset, locale: _locale);
      if (generation != _searchGeneration) return;
      _results = [
        ..._results,
        ...page.items.where((i) => !_results.any((r) => r.id == i.id)),
      ];
      _resultsNext = page.items.isEmpty ? null : page.nextOffset;
    } catch (e) {
      debugLog('[TrimzState] Search failed: $e');
      if (generation != _searchGeneration) return;
      _searchFailed = true;
    }
    _searching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchGeneration++;
    _query = '';
    _results = const [];
    _resultsNext = null;
    _searching = false;
    _searchFailed = false;
  }

  Future<TrimzSeriesDetail> loadSeries(String slug) async {
    final cached = _details[slug];
    if (cached != null) return cached;
    final detail = await _api.series(slug, locale: _locale);
    _details[slug] = detail;
    return detail;
  }

  Future<void> toggleList(TrimzSeries series) async {
    final current = _saved[series.id] ?? TrimzSavedSeries.of(series);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store(current.copyWith(savedAt: () => current.onList ? null : now));
  }

  /// Where the viewer is in [series]; the player calls it while it plays.
  Future<void> recordProgress(
    TrimzSeries series, {
    required int episodeIndex,
    required int episodeCount,
    required Duration position,
    required Duration duration,
  }) async {
    final current = _saved[series.id] ?? TrimzSavedSeries.of(series);
    await _store(
      current.copyWith(
        title: series.title,
        posterUrl: series.posterUrl,
        episodeCount: episodeCount,
        episodeIndex: episodeIndex,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        watchedAt: () => DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> forgetProgress(String id) async {
    final current = _saved[id];
    if (current == null) return;
    await _store(
      current.copyWith(
        episodeIndex: 0,
        positionMs: 0,
        durationMs: 0,
        watchedAt: () => null,
      ),
    );
  }

  Future<void> _store(TrimzSavedSeries series) async {
    final keep = series.watched || series.onList;
    _saved = {..._saved}..remove(series.id);
    if (keep) _saved[series.id] = series;
    notifyListeners();
    try {
      if (keep) {
        await _db.save(series);
      } else {
        await _db.delete(series.id);
      }
    } catch (e) {
      errorLog('[TrimzState] Saving ${series.id} failed: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      await _db.clearHistory();
    } catch (e) {
      errorLog('[TrimzState] Clearing history failed: $e');
    }
    await _loadSaved();
  }

  Future<void> clearList() async {
    try {
      await _db.clearList();
    } catch (e) {
      errorLog('[TrimzState] Clearing list failed: $e');
    }
    await _loadSaved();
  }

  Future<void> setAdaptiveStream(bool value) async {
    _adaptiveStream = value;
    notifyListeners();
    await _saveSetting(_adaptiveKey, value);
  }

  Future<void> setAutoplayNext(bool value) async {
    _autoplayNext = value;
    notifyListeners();
    await _saveSetting(_autoplayKey, value);
  }

  Future<void> setTranslatedTitles(bool value) async {
    if (value == _translatedTitles) return;
    _translatedTitles = value;
    notifyListeners();
    await _saveSetting(_translatedKey, value);
    if (_appLanguage != 'en') await refresh();
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      await DatabaseService.instance.setSetting(
        TrimzTool.config.id,
        key,
        '$value',
      );
    } catch (e) {
      errorLog('[TrimzState] Saving $key failed: $e');
    }
  }
}

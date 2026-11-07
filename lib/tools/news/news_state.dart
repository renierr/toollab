import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'news_article.dart';
import 'news_article_service.dart';
import 'news_catalog.dart';
import 'news_db_helper.dart';
import 'news_feed_service.dart';
import 'news_source.dart';

class NewsSourceExistsException implements Exception {
  const NewsSourceExistsException();
}

class NewsState extends ChangeNotifier {
  static String get _toolId => NewsTool.config.id;
  static const String _keyHideRead = 'hide_read';
  static const String _keyMarkOnScroll = 'mark_read_on_scroll';
  static const String _keyRefreshOnOpen = 'refresh_on_open';
  static const String _keySelectedSource = 'selected_source';
  static const String _keySeedDone = 'seed_done';
  static const String _keyLastRefresh = 'last_refresh_at';
  static const String _keyReaderFontPercent = 'reader_font_percent';

  static const int minReaderFontPercent = 80;
  static const int maxReaderFontPercent = 200;
  static const int readerFontStep = 10;

  static const Duration _autoRefreshInterval = Duration(minutes: 10);
  static const int _refreshWorkers = 3;
  static const int _previewWorkers = 2;
  static const int _maxQueuedPreviews = 12;

  List<NewsSource> _sources = [];
  Map<String, NewsSource> _sourceMap = {};
  List<NewsArticle> _articles = [];
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _selectedSourceId;
  bool _hideRead = false;
  bool _markReadOnScroll = true;
  bool _refreshOnOpen = true;
  int _lastRefreshAt = 0;
  int _lastRefreshAdded = 0;
  int _lastRefreshFailures = 0;
  int _readerFontPercent = 100;
  Future<void> _readerFontSave = Future.value();
  Future<void>? _initialization;
  Completer<void>? _refreshCompletion;
  int _readFilterCutoff = DateTime.now().millisecondsSinceEpoch;
  int _lastReadAt = 0;
  final Map<int, int> _pendingReads = {};
  final Set<Future<void>> _pendingReadWrites = {};
  final Queue<NewsArticle> _previewQueue = Queue();
  final Set<String> _previewAttempts = {};
  final Map<String, Future<ExtractedArticle>> _articleFetches = {};
  int _activePreviews = 0;
  bool _disposed = false;

  List<NewsSource> get sources => _sources;
  List<NewsArticle> get articles => _articles;
  Map<String, int> get unreadCounts => _unreadCounts;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get selectedSourceId => _selectedSourceId;
  bool get hideRead => _hideRead;
  bool get markReadOnScroll => _markReadOnScroll;
  bool get refreshOnOpen => _refreshOnOpen;
  int get lastRefreshAt => _lastRefreshAt;
  int get lastRefreshAdded => _lastRefreshAdded;
  int get lastRefreshFailures => _lastRefreshFailures;
  int get readerFontPercent => _readerFontPercent;
  double get readerFontScale => _readerFontPercent / 100;
  int get totalUnread =>
      _unreadCounts.values.fold(0, (sum, count) => sum + count);
  List<NewsSource> get enabledSources =>
      _sources.where((source) => source.enabled).toList();

  NewsSource? sourceFor(String shortId) => _sourceMap[shortId];

  String sourceTitle(String shortId) => _sourceMap[shortId]?.title ?? shortId;

  Future<void> init() => _initialization ??= _doInit();

  Future<void> _doInit() async {
    try {
      await _loadSettings();
      await _seedIfNeeded();
      await reload();
      if (_refreshOnOpen && _shouldAutoRefresh) {
        unawaited(refresh());
      }
    } catch (e) {
      errorLog('[NewsState] Initialization failed: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get _shouldAutoRefresh {
    if (_lastRefreshAt == 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - _lastRefreshAt;
    return age >= _autoRefreshInterval.inMilliseconds;
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    _hideRead = (await db.getSetting(_toolId, _keyHideRead)) == 'true';
    _markReadOnScroll =
        (await db.getSetting(_toolId, _keyMarkOnScroll)) != 'false';
    _refreshOnOpen =
        (await db.getSetting(_toolId, _keyRefreshOnOpen)) != 'false';
    _selectedSourceId = await db.getSetting(_toolId, _keySelectedSource);
    if (_selectedSourceId != null && _selectedSourceId!.isEmpty) {
      _selectedSourceId = null;
    }
    _lastRefreshAt =
        int.tryParse(await db.getSetting(_toolId, _keyLastRefresh) ?? '') ?? 0;
    _readerFontPercent =
        (int.tryParse(
                  await db.getSetting(_toolId, _keyReaderFontPercent) ?? '',
                ) ??
                100)
            .clamp(minReaderFontPercent, maxReaderFontPercent);
  }

  Future<void> _seedIfNeeded() async {
    final db = DatabaseService.instance;
    if (await db.getSetting(_toolId, _keySeedDone) == 'true') return;
    final existing = await NewsDbHelper.instance.getSources();
    if (existing.isEmpty) {
      var order = 0;
      for (final seed in NewsCatalog.seeds) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await NewsDbHelper.instance.saveSource(
          NewsSource(
            shortId: NewsCatalog.shortIdForFeed(seed.feedUrl),
            title: seed.title,
            feedUrl: seed.feedUrl,
            siteUrl: seed.siteUrl,
            category: NewsCatalog.categoryForFeed(seed.feedUrl) ?? 'top',
            enabled: seed.enabledByDefault,
            sortOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    await db.setSetting(_toolId, _keySeedDone, 'true');
  }

  Future<void> reload() async {
    _sources = await NewsDbHelper.instance.getSources();
    _sourceMap = {for (final source in _sources) source.shortId: source};
    if (_selectedSourceId != null &&
        (_sourceMap[_selectedSourceId]?.enabled != true)) {
      _selectedSourceId = null;
      await DatabaseService.instance.setSetting(
        _toolId,
        _keySelectedSource,
        '',
      );
    }
    await _reloadArticles();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reloadArticles() async {
    _articles = await NewsDbHelper.instance.getArticles(
      sourceShortId: _selectedSourceId,
      unreadOnly: _hideRead,
      readAfter: _readFilterCutoff,
    );
    _unreadCounts = await NewsDbHelper.instance.getUnreadCounts();
    for (var index = 0; index < _articles.length; index++) {
      final article = _articles[index];
      final pendingAt = _pendingReads[article.id];
      if (pendingAt != null && !article.isRead) {
        _articles[index] = article.copyWith(readAt: pendingAt);
        final count = _unreadCounts[article.sourceShortId] ?? 0;
        _unreadCounts[article.sourceShortId] = max(0, count - 1);
      }
    }
  }

  Future<void> setSelectedSource(String? shortId) async {
    _selectedSourceId = shortId;
    await DatabaseService.instance.setSetting(
      _toolId,
      _keySelectedSource,
      shortId ?? '',
    );
    await _reloadArticles();
    notifyListeners();
  }

  Future<void> setHideRead(bool value) async {
    if (value && !_hideRead) _resetReadFilterCutoff();
    _hideRead = value;
    await DatabaseService.instance.setSetting(
      _toolId,
      _keyHideRead,
      value ? 'true' : 'false',
    );
    await _reloadArticles();
    notifyListeners();
  }

  Future<void> setMarkReadOnScroll(bool value) async {
    _markReadOnScroll = value;
    await DatabaseService.instance.setSetting(
      _toolId,
      _keyMarkOnScroll,
      value ? 'true' : 'false',
    );
    notifyListeners();
  }

  Future<void> setRefreshOnOpen(bool value) async {
    _refreshOnOpen = value;
    await DatabaseService.instance.setSetting(
      _toolId,
      _keyRefreshOnOpen,
      value ? 'true' : 'false',
    );
    notifyListeners();
  }

  Future<void> setReaderFontPercent(int value) {
    final next = value.clamp(minReaderFontPercent, maxReaderFontPercent);
    if (next == _readerFontPercent) return _readerFontSave;
    _readerFontPercent = next;
    notifyListeners();
    _readerFontSave = _readerFontSave.then((_) async {
      try {
        await DatabaseService.instance.setSetting(
          _toolId,
          _keyReaderFontPercent,
          '$next',
        );
      } catch (e) {
        errorLog('[NewsState] Failed to save reader font size: $e');
      }
    });
    return _readerFontSave;
  }

  Future<void> refresh({List<NewsSource>? only}) async {
    if (_isRefreshing) {
      await _refreshCompletion?.future;
      if (only != null) {
        final ids = only.map((source) => source.shortId).toSet();
        await refresh(
          only: _sources.where((s) => ids.contains(s.shortId)).toList(),
        );
      }
      return;
    }
    final targets = (only ?? enabledSources)
        .where((source) => source.enabled || only != null)
        .toList();
    if (targets.isEmpty) {
      await _waitForReadWrites();
      _resetReadFilterCutoff();
      await reload();
      return;
    }

    _isRefreshing = true;
    final completion = _refreshCompletion = Completer<void>();
    notifyListeners();

    var added = 0;
    var failures = 0;
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= targets.length) return;
        final source = targets[index];
        try {
          final result = await NewsFeedService.fetch(source);
          final current = await NewsDbHelper.instance.getSource(source.shortId);
          if (current == null ||
              current.deleted ||
              current.feedUrl != source.feedUrl) {
            continue;
          }
          if (result.notModified) {
            await NewsDbHelper.instance.updateFetchState(
              source.shortId,
              keepValidators: true,
            );
            continue;
          }
          final feed = result.feed;
          if (feed == null) continue;
          final fetchedAt = DateTime.now().millisecondsSinceEpoch;
          added += await NewsDbHelper.instance.saveFetchedArticles(
            source.shortId,
            feed.items
                .map(
                  (item) => item.toArticle(
                    sourceShortId: source.shortId,
                    fetchedAt: fetchedAt,
                  ),
                )
                .toList(),
          );
          await NewsDbHelper.instance.updateFetchState(
            source.shortId,
            etag: result.etag,
            lastModified: result.lastModified,
          );
        } catch (e) {
          failures++;
          debugLog('[NewsState] Feed failed for ${source.feedUrl}: $e');
          await NewsDbHelper.instance.updateFetchState(
            source.shortId,
            keepValidators: true,
            error: _describeError(e),
          );
        }
      }
    }

    try {
      final workers = min(_refreshWorkers, targets.length);
      await Future.wait(List.generate(workers, (_) => worker()));
      await NewsDbHelper.instance.prune();
      _lastRefreshAdded = added;
      _lastRefreshFailures = failures;
      _lastRefreshAt = DateTime.now().millisecondsSinceEpoch;
      await DatabaseService.instance.setSetting(
        _toolId,
        _keyLastRefresh,
        '$_lastRefreshAt',
      );
    } catch (e) {
      errorLog('[NewsState] Refresh failed: $e');
    } finally {
      _isRefreshing = false;
      try {
        await _waitForReadWrites();
        _resetReadFilterCutoff();
        await reload();
      } finally {
        completion.complete();
      }
    }
  }

  static String _describeError(Object error) {
    if (error is NewsFeedException) return error.message;
    return error.toString();
  }

  Future<NewsSource> addCatalogSource(
    NewsCatalogSource catalogSource,
    String categoryId,
  ) async {
    final existing = await NewsDbHelper.instance.getSourceByFeedUrl(
      catalogSource.feedUrl,
    );
    if (existing != null) {
      if (!existing.enabled) {
        await setSourceEnabled(existing, true);
      }
      return existing;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final saved = await NewsDbHelper.instance.saveSource(
      NewsSource(
        shortId: NewsCatalog.shortIdForFeed(catalogSource.feedUrl),
        title: catalogSource.title,
        feedUrl: catalogSource.feedUrl,
        siteUrl: catalogSource.siteUrl,
        category: categoryId,
        sortOrder: await NewsDbHelper.instance.getNextSortOrder(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await reload();
    unawaited(refresh(only: [saved]));
    return saved;
  }

  Future<NewsSource> addCustomSource({
    required String feedUrl,
    String? title,
    String category = NewsCatalog.customCategory,
  }) async {
    final normalized = feedUrl.trim();
    final existing = await NewsDbHelper.instance.getSourceByFeedUrl(normalized);
    if (existing != null) throw const NewsSourceExistsException();

    final feed = await NewsFeedService.probe(normalized);
    final now = DateTime.now().millisecondsSinceEpoch;
    final shortId = NewsCatalog.shortIdForFeed(normalized);
    final saved = await NewsDbHelper.instance.saveSource(
      NewsSource(
        shortId: shortId,
        title: (title ?? '').trim().isNotEmpty
            ? title!.trim()
            : (feed.title.isNotEmpty ? feed.title : Uri.parse(normalized).host),
        feedUrl: normalized,
        siteUrl: feed.siteUrl,
        category: category,
        sortOrder: await NewsDbHelper.instance.getNextSortOrder(),
        createdAt: now,
        updatedAt: now,
        lastFetchedAt: now,
      ),
    );

    final fetchedAt = DateTime.now().millisecondsSinceEpoch;
    await NewsDbHelper.instance.saveFetchedArticles(
      shortId,
      feed.items
          .map(
            (item) =>
                item.toArticle(sourceShortId: shortId, fetchedAt: fetchedAt),
          )
          .toList(),
    );
    await reload();
    return saved;
  }

  Future<NewsSource?> sourceByFeedUrl(String feedUrl) =>
      NewsDbHelper.instance.getSourceByFeedUrl(feedUrl);

  Future<void> updateSource(
    NewsSource source, {
    bool feedChanged = false,
  }) async {
    final saved = await NewsDbHelper.instance.saveSource(
      feedChanged ? source.copyWith(clearEtag: true, clearError: true) : source,
    );
    await reload();
    if (feedChanged) unawaited(refresh(only: [saved]));
  }

  Future<void> setSourceEnabled(NewsSource source, bool enabled) async {
    await updateSource(source.copyWith(enabled: enabled));
  }

  Future<void> deleteSource(NewsSource source) async {
    await NewsDbHelper.instance.deleteSource(source.shortId);
    await reload();
  }

  Future<void> markRead(NewsArticle article) async {
    final id = article.id;
    if (id == null || article.isRead || _pendingReads.containsKey(id)) return;
    final current = _articles.where((item) => item.id == id).firstOrNull;
    if (current == null || current.isRead) return;
    final now = _nextReadTime();
    _pendingReads[id] = now;
    _articles = [
      for (final item in _articles)
        if (item.id == id) item.copyWith(readAt: now) else item,
    ];
    final count = _unreadCounts[article.sourceShortId] ?? 0;
    _unreadCounts[article.sourceShortId] = max(0, count - 1);
    final write = NewsDbHelper.instance.markRead(id, readAt: now);
    _pendingReadWrites.add(write);
    notifyListeners();
    try {
      await write;
    } catch (e) {
      errorLog('[NewsState] Failed to mark article read: $e');
      _pendingReads.remove(id);
      await reload();
      return;
    } finally {
      _pendingReadWrites.remove(write);
    }
    _pendingReads.remove(id);
  }

  Future<void> markAllRead({String? sourceShortId}) async {
    await NewsDbHelper.instance.markAllRead(
      sourceShortId: sourceShortId,
      readAt: _nextReadTime(),
    );
    await reload();
  }

  int _nextReadTime() {
    _lastReadAt = max(
      DateTime.now().millisecondsSinceEpoch,
      max(_readFilterCutoff + 1, _lastReadAt + 1),
    );
    return _lastReadAt;
  }

  void _resetReadFilterCutoff() {
    _readFilterCutoff = max(DateTime.now().millisecondsSinceEpoch, _lastReadAt);
  }

  Future<void> _waitForReadWrites() async {
    while (_pendingReadWrites.isNotEmpty) {
      await Future.wait(
        _pendingReadWrites.map((write) async {
          try {
            await write;
          } catch (_) {}
        }).toList(),
      );
    }
  }

  Future<void> clearCachedArticles() async {
    _previewQueue.clear();
    _previewAttempts.clear();
    await NewsDbHelper.instance.clearArticles();
    await reload();
  }

  Future<ExtractedArticle> loadArticleBody(NewsArticle article) async {
    final cached = await NewsDbHelper.instance.getArticleContent(
      article.guidKey,
    );
    if (cached != null && cached.trim().isNotEmpty) {
      final current = _articles
          .where((item) => item.guidKey == article.guidKey)
          .firstOrNull;
      return ExtractedArticle(
        markdown: NewsArticleService.cleanCachedMarkdown(
          cached,
          title: article.title,
          author: article.author,
          heroImageUrl: current?.imageUrl ?? article.imageUrl,
        ),
        imageUrl: current?.imageUrl ?? article.imageUrl,
        title: null,
      );
    }
    final extracted = await _fetchArticle(article);
    if (extracted.markdown.isEmpty) return _fetchArticle(article);
    return extracted;
  }

  void prefetchArticleImage(NewsArticle article) {
    if (_disposed ||
        (article.imageUrl ?? '').isNotEmpty ||
        article.link.isEmpty ||
        _previewAttempts.contains(article.guidKey)) {
      return;
    }
    final current = _articles
        .where((item) => item.guidKey == article.guidKey)
        .firstOrNull;
    if (current == null || (current.imageUrl ?? '').isNotEmpty) return;
    if (_previewQueue.length >= _maxQueuedPreviews) {
      _previewAttempts.remove(_previewQueue.removeFirst().guidKey);
    }
    _previewAttempts.add(article.guidKey);
    _previewQueue.add(current);
    _drainPreviewQueue();
  }

  void _drainPreviewQueue() {
    while (!_disposed &&
        _activePreviews < _previewWorkers &&
        _previewQueue.isNotEmpty) {
      final article = _previewQueue.removeFirst();
      _activePreviews++;
      unawaited(_runPreview(article));
    }
  }

  Future<void> _runPreview(NewsArticle article) async {
    try {
      await _fetchArticle(article, allowImageOnly: true);
    } catch (e) {
      debugLog('[NewsState] Preview failed for ${article.link}: $e');
    } finally {
      _activePreviews--;
      _drainPreviewQueue();
    }
  }

  Future<ExtractedArticle> _fetchArticle(
    NewsArticle article, {
    bool allowImageOnly = false,
  }) async {
    final fetch = _articleFetches.putIfAbsent(
      article.guidKey,
      () => _fetchAndCacheArticle(article, allowImageOnly: allowImageOnly),
    );
    try {
      return await fetch;
    } finally {
      if (identical(_articleFetches[article.guidKey], fetch)) {
        _articleFetches.remove(article.guidKey);
      }
    }
  }

  Future<ExtractedArticle> _fetchAndCacheArticle(
    NewsArticle article, {
    required bool allowImageOnly,
  }) async {
    final extracted = await NewsArticleService.fetch(
      article,
      allowImageOnly: allowImageOnly,
    );
    await NewsDbHelper.instance.setArticleContent(
      article.guidKey,
      extracted.markdown,
      imageUrl: extracted.imageUrl,
    );
    final image = extracted.imageUrl;
    if (!_disposed && image != null && image.isNotEmpty) {
      final current = _articles
          .where((item) => item.guidKey == article.guidKey)
          .firstOrNull;
      if (current == null || (current.imageUrl ?? '').isNotEmpty) {
        return extracted;
      }
      _articles = [
        for (final item in _articles)
          if (item.guidKey == article.guidKey && (item.imageUrl ?? '').isEmpty)
            item.copyWith(imageUrl: image)
          else
            item,
      ];
      notifyListeners();
    }
    return extracted;
  }

  @override
  void dispose() {
    _disposed = true;
    _previewQueue.clear();
    super.dispose();
  }
}

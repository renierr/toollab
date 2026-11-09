import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'news_article.dart';
import 'news_article_service.dart';
import 'news_catalog.dart';
import 'news_db_helper.dart';
import 'news_error.dart';
import 'news_feed_parser.dart';
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
  static const Duration _readFlushDelay = Duration(milliseconds: 250);
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
  Timer? _unreadExpiryTimer;
  Completer<void>? _refreshCompletion;
  int _readFilterCutoff = DateTime.now().millisecondsSinceEpoch;
  int _lastReadAt = 0;
  int _readGeneration = 0;
  int _articlesGeneration = 0;
  final Map<int, int> _pendingReads = {};
  // Article id -> reload generation current when its read was stored.
  final Map<int, int> _storedReads = {};
  // Reads shown in the UI but not yet written; flushed together.
  final Map<int, int> _queuedReads = {};
  final Map<int, int> _unshownReads = {};
  bool _readsShowScheduled = false;
  Timer? _readFlushTimer;
  Completer<void>? _nextReadFlush;
  Future<void> _readWrites = Future.value();
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
  int get readGeneration => _readGeneration;
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
    final generation = ++_articlesGeneration;
    final cutoff = NewsDbHelper.newArticleCutoff();
    final articles = await NewsDbHelper.instance.getArticles(
      sourceShortId: _selectedSourceId,
      unreadOnly: _hideRead,
      readAfter: _readFilterCutoff,
      newSince: cutoff,
    );
    final unreadCounts = await NewsDbHelper.instance.getUnreadCounts(
      newSince: cutoff,
    );
    final expiry = await NewsDbHelper.instance.getNextUnreadExpiry(
      newSince: cutoff,
    );
    // A later reload, e.g. from a quick filter change, owns the list now.
    if (generation != _articlesGeneration) return;
    // Only a reload started after the write has read it back from the DB.
    _storedReads.removeWhere((id, storedAt) {
      if (storedAt >= generation) return false;
      _pendingReads.remove(id);
      return true;
    });
    for (var index = 0; index < articles.length; index++) {
      final article = articles[index];
      final pendingAt = _pendingReads[article.id];
      if (pendingAt != null && article.readAt == null) {
        articles[index] = article.copyWith(readAt: pendingAt);
        if (!article.isRead) {
          final count = unreadCounts[article.sourceShortId] ?? 0;
          unreadCounts[article.sourceShortId] = max(0, count - 1);
        }
      }
    }
    _articles = articles;
    _unreadCounts = unreadCounts;
    _unreadExpiryTimer?.cancel();
    if (expiry != null && !_disposed) {
      final delay = max(1, expiry - DateTime.now().millisecondsSinceEpoch);
      _unreadExpiryTimer = Timer(Duration(milliseconds: delay), () async {
        try {
          await _reloadArticles();
          if (!_disposed) notifyListeners();
        } catch (e) {
          errorLog('[NewsState] Failed to update expired articles: $e');
        }
      });
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
      await flushReads();
      _resetReadFilterCutoff();
      await reload();
      return;
    }

    _isRefreshing = true;
    final completion = _refreshCompletion = Completer<void>();
    notifyListeners();

    var added = 0;
    var failures = 0;
    final pending = Queue.of(targets);

    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final result = await _refreshSource(pending.removeFirst());
        if (result == null) {
          failures++;
        } else {
          added += result;
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
        await flushReads();
        _resetReadFilterCutoff();
        await reload();
      } catch (e) {
        errorLog('[NewsState] Reload after refresh failed: $e');
        if (!_disposed) notifyListeners();
      } finally {
        completion.complete();
      }
    }
  }

  /// Returns the number of new articles, or null when the feed failed.
  Future<int?> _refreshSource(NewsSource source) async {
    final db = NewsDbHelper.instance;
    try {
      final result = await NewsFeedService.fetch(source);
      final current = await db.getSource(source.shortId);
      if (current == null ||
          current.deleted ||
          current.feedUrl != source.feedUrl) {
        return 0;
      }
      final feed = result.feed;
      if (result.notModified || feed == null) {
        await db.updateFetchState(source.shortId, keepValidators: true);
        return 0;
      }
      final added = await db.saveFetchedArticles(
        source.shortId,
        _articlesOf(feed, source.shortId),
      );
      await db.updateFetchState(
        source.shortId,
        etag: result.etag,
        lastModified: result.lastModified,
      );
      return added;
    } catch (e) {
      debugLog('[NewsState] Feed failed for ${source.feedUrl}: $e');
      try {
        await db.updateFetchState(
          source.shortId,
          keepValidators: true,
          error: e is NewsException ? e.code : '$e',
        );
      } catch (e) {
        errorLog('[NewsState] Failed to store feed error: $e');
      }
      return null;
    }
  }

  static List<NewsArticle> _articlesOf(ParsedFeed feed, String shortId) {
    final fetchedAt = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final item in feed.items)
        item.toArticle(sourceShortId: shortId, fetchedAt: fetchedAt),
    ];
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
        shortId: await NewsDbHelper.instance.availableShortId(
          catalogSource.feedUrl,
        ),
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

    final shortId = await NewsDbHelper.instance.availableShortId(normalized);
    final feed = await NewsFeedService.probe(normalized, shortId: shortId);
    final now = DateTime.now().millisecondsSinceEpoch;
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

    await NewsDbHelper.instance.saveFetchedArticles(
      shortId,
      _articlesOf(feed, shortId),
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

  bool get hasUnsavedReads => _queuedReads.isNotEmpty;

  /// Shows the read at once and stores it with the other reads of the next
  /// [_readFlushDelay]; [immediate] stores everything queued right away.
  /// Completes once the read is stored.
  Future<void> markRead(NewsArticle article, {bool immediate = false}) {
    final id = article.id;
    if (id != null &&
        article.readAt == null &&
        !_pendingReads.containsKey(id) &&
        _articles.any((item) => item.id == id && item.readAt == null)) {
      final readAt = _nextReadTime();
      _pendingReads[id] = readAt;
      _queuedReads[id] = readAt;
      _unshownReads[id] = readAt;
      if (!_readsShowScheduled) {
        _readsShowScheduled = true;
        scheduleMicrotask(_showQueuedReads);
      }
    }
    if (immediate) return flushReads();
    if (_queuedReads.isEmpty) return _readWrites;
    _readFlushTimer ??= Timer(_readFlushDelay, () => unawaited(flushReads()));
    return (_nextReadFlush ??= Completer<void>()).future;
  }

  // Cards passing in one frame become one list update instead of one each.
  void _showQueuedReads() {
    _readsShowScheduled = false;
    if (_disposed || _unshownReads.isEmpty) return;
    final reads = Map.of(_unshownReads);
    _unshownReads.clear();
    final articles = [..._articles];
    var changed = false;
    for (var index = 0; index < articles.length; index++) {
      final item = articles[index];
      final readAt = reads[item.id];
      if (readAt == null || item.readAt != null) continue;
      articles[index] = item.copyWith(readAt: readAt);
      changed = true;
      if (!item.isRead) {
        final count = _unreadCounts[item.sourceShortId] ?? 0;
        _unreadCounts[item.sourceShortId] = max(0, count - 1);
      }
    }
    if (!changed) return;
    _articles = articles;
    notifyListeners();
  }

  /// Stores all queued reads; completes when every earlier write has landed.
  Future<void> flushReads() {
    _readFlushTimer?.cancel();
    _readFlushTimer = null;
    final done = _nextReadFlush;
    _nextReadFlush = null;
    if (_queuedReads.isNotEmpty) {
      final reads = Map.of(_queuedReads);
      _queuedReads.clear();
      _readWrites = _readWrites.then((_) => _writeReads(reads));
    }
    if (done != null) unawaited(_readWrites.then((_) => done.complete()));
    return _readWrites;
  }

  Future<void> _writeReads(Map<int, int> reads) async {
    try {
      await NewsDbHelper.instance.markReads(reads);
    } catch (e) {
      errorLog('[NewsState] Failed to mark articles read: $e');
      reads.keys.forEach(_pendingReads.remove);
      if (_disposed) return;
      try {
        await reload();
      } catch (e) {
        errorLog('[NewsState] Reload after failed read write failed: $e');
      }
      return;
    }
    for (final id in reads.keys) {
      _storedReads[id] = _articlesGeneration;
    }
    _readGeneration++;
    if (!_disposed) notifyListeners();
  }

  Future<void> markAllRead({String? sourceShortId}) async {
    await NewsDbHelper.instance.markAllRead(
      sourceShortId: sourceShortId,
      readAt: _nextReadTime(),
    );
    _readGeneration++;
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

  Future<void> clearCachedArticles() async {
    _previewQueue.clear();
    _previewAttempts.clear();
    await NewsDbHelper.instance.clearArticles();
    await reload();
  }

  Future<ExtractedArticle> loadArticleBody(NewsArticle article) async {
    final cached = await NewsDbHelper.instance.getCachedContent(
      article.guidKey,
    );
    final markdown = cached?.markdown;
    if (cached != null && markdown != null) {
      final heroImageUrl =
          _articles
              .where((item) => item.guidKey == article.guidKey)
              .firstOrNull
              ?.imageUrl ??
          article.imageUrl;
      final title = article.title;
      final author = article.author;
      final saved = ExtractedArticle(
        markdown: await Isolate.run(
          () => NewsArticleService.cleanCachedMarkdown(
            markdown,
            title: title,
            author: author,
            heroImageUrl: heroImageUrl,
          ),
        ),
        imageUrl: heroImageUrl,
        title: null,
        videoUrls: cached.videoUrls ?? const [],
      );
      if (cached.videoUrls != null) return saved;
      try {
        final refreshed = await _fetchArticle(article);
        if (refreshed.markdown.isNotEmpty || refreshed.videoUrls.isNotEmpty) {
          return refreshed;
        }
        return saved;
      } catch (_) {
        return saved;
      }
    }
    final extracted = await _fetchArticle(article);
    // Joined an image preview that already found no body on the same page.
    if (extracted.markdown.isEmpty && extracted.videoUrls.isEmpty) {
      throw const NewsException(NewsError.noArticleBody);
    }
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
      videoUrls: extracted.videoUrls,
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
    unawaited(flushReads());
    _disposed = true;
    _unreadExpiryTimer?.cancel();
    _previewQueue.clear();
    super.dispose();
  }
}

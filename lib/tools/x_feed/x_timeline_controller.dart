import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'api/x_api.dart';
import 'models/x_post.dart';

typedef XTimelineFetch = Future<XTimelinePage> Function(String? cursor);

/// One paged list of posts: a home tab, a profile, a search or a thread.
class XTimelineController extends ChangeNotifier {
  /// Pages without a new post fetched in a row before the end is assumed;
  /// For you serves pages of duplicates or filtered ads mid-feed.
  static const int _emptyPageAttempts = 3;

  final XTimelineFetch _fetch;
  final void Function(XApiException error)? onError;

  XTimelineController(this._fetch, {this.onError});

  List<XPost> _posts = const [];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _endReached = false;
  bool _loaded = false;
  XApiException? _error;
  int _generation = 0;
  int _refreshes = 0;
  bool _disposed = false;

  List<XPost> get posts => _posts;

  /// Bumps each time a refresh replaces the posts.
  int get refreshCount => _refreshes;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get endReached => _endReached;

  /// The end may be a false one: X still handed out a cursor.
  bool get canRetryEnd => _endReached && _cursor != null;
  bool get isLoaded => _loaded;
  XApiException? get error => _error;

  Future<void> ensureLoaded() async {
    if (!_loaded && !_loading) await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    // An in-flight loadMore is dropped by the generation bump and never clears this.
    _loadingMore = false;
    _error = null;
    _notify();
    try {
      final page = await _fetch(null);
      if (generation != _generation) return;
      _posts = page.posts;
      _cursor = page.bottomCursor;
      _endReached = page.bottomCursor == null || page.posts.isEmpty;
      _loaded = true;
      _refreshes++;
    } catch (e) {
      if (generation != _generation) return;
      _fail(e);
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_loading || _loadingMore || _endReached || cursor == null) return;
    final generation = _generation;
    _loadingMore = true;
    _error = null;
    _notify();
    try {
      final known = {for (final p in _posts) p.id};
      String? next = cursor;
      var fresh = <XPost>[];
      for (var attempt = 0; attempt < _emptyPageAttempts; attempt++) {
        final page = await _fetch(next);
        if (generation != _generation) return;
        final previous = next;
        next = page.bottomCursor;
        fresh = page.posts.where((p) => !known.contains(p.id)).toList();
        if (fresh.isNotEmpty || next == null || next == previous) break;
      }
      _posts = [..._posts, ...fresh];
      _cursor = next;
      // X keeps handing out cursors at the end; empty pages mean done.
      _endReached = next == null || fresh.isEmpty;
    } catch (e) {
      if (generation != _generation) return;
      _fail(e);
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// Parser bugs surface as errors too; otherwise the footer spins forever.
  /// Tries again past an end that [canRetryEnd] says may be a false one.
  Future<void> retryEnd() {
    if (!canRetryEnd) return Future.value();
    _endReached = false;
    return loadMore();
  }

  void _fail(Object e) {
    errorLog('[XTimeline] Load failed: $e');
    final error = e is XApiException
        ? e
        : XApiException(XApiErrorKind.server, '$e');
    _error = error;
    onError?.call(error);
  }

  void reset() {
    _generation++;
    _posts = const [];
    _cursor = null;
    _loading = false;
    _loadingMore = false;
    _endReached = false;
    _loaded = false;
    _error = null;
    _notify();
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

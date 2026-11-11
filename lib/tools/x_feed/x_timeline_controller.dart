import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'api/x_api.dart';
import 'models/x_post.dart';

typedef XTimelineFetch = Future<XTimelinePage> Function(String? cursor);

/// One paged list of posts: a home tab, a profile, a search or a thread.
class XTimelineController extends ChangeNotifier {
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
  bool get isLoaded => _loaded;
  XApiException? get error => _error;

  Future<void> ensureLoaded() async {
    if (!_loaded && !_loading) await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
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
    } on XApiException catch (e) {
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
      final page = await _fetch(cursor);
      if (generation != _generation) return;
      final known = {for (final p in _posts) p.id};
      final fresh = page.posts.where((p) => !known.contains(p.id)).toList();
      _posts = [..._posts, ...fresh];
      _cursor = page.bottomCursor;
      // X keeps handing out cursors at the end; an empty page means done.
      _endReached = page.bottomCursor == null || fresh.isEmpty;
    } on XApiException catch (e) {
      if (generation != _generation) return;
      _fail(e);
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  void _fail(XApiException e) {
    errorLog('[XTimeline] Load failed: $e');
    _error = e;
    onError?.call(e);
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

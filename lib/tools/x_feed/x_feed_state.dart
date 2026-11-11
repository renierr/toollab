import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import 'api/x_api.dart';
import 'api/x_session.dart';
import 'api/x_web_config.dart';
import 'config.dart';
import 'models/x_post.dart';
import 'x_timeline_controller.dart';

enum XFeedTab { forYou, following, bookmarks, search }

enum XSessionStatus { unknown, loggedOut, loggedIn }

class XFeedState extends ChangeNotifier {
  static const String _hideRepostsKey = 'hide_reposts';
  static const String _hideRepliesKey = 'hide_replies';
  static const String _startTabKey = 'start_tab';
  static const String _seenKey = 'seen_pending';
  static const String _textScaleKey = 'text_scale';

  static const List<double> textScales = [0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

  /// Keeps the GET query string of a home request well under URL limits.
  static const int _seenBatchLimit = 100;

  XSessionStatus _status = XSessionStatus.unknown;
  bool _sessionExpired = false;
  String? _screenName;
  XApi? _api;
  bool _initialized = false;
  bool _disposed = false;

  bool _hideReposts = false;
  bool _hideReplies = false;
  double _textScale = 1.0;
  XFeedTab _startTab = XFeedTab.forYou;
  XFeedTab _tab = XFeedTab.forYou;

  final Map<String, XEngagement> _engagement = {};

  /// Downloads for sharing and saving.
  final TempFileScope tempScope = TempFileManager.createScope();

  /// Posts seen since the last home request, oldest first. They ride along
  /// with the next home timeline request, so X gets them in one batch.
  final LinkedHashSet<String> _seenPending = LinkedHashSet();
  final Set<String> _seenSent = {};
  Timer? _seenSave;

  late final XTimelineController forYou = _timeline(
    (cursor) => _homeTimeline(following: false, cursor: cursor),
  );
  late final XTimelineController following = _timeline(
    (cursor) => _homeTimeline(following: true, cursor: cursor),
  );
  late final XTimelineController bookmarks = _timeline(
    (cursor) => _requireApi().bookmarks(cursor: cursor),
  );

  XSessionStatus get status => _status;
  bool get sessionExpired => _sessionExpired;
  String? get screenName => _screenName;
  bool get hideReposts => _hideReposts;
  bool get hideReplies => _hideReplies;

  /// Multiplies the system text scale inside posts.
  double get textScale => _textScale;
  XFeedTab get startTab => _startTab;
  XFeedTab get tab => _tab;

  XSession? get session => _api?.session;

  /// The API for pages that build their own timelines (profile, search, thread).
  XApi get api => _requireApi();

  XApi _requireApi() {
    final api = _api;
    if (api == null) throw const XApiException(XApiErrorKind.unauthorized);
    return api;
  }

  XTimelineController timeline(XTimelineFetch fetch) => _timeline(fetch);

  XTimelineController _timeline(XTimelineFetch fetch) =>
      XTimelineController(fetch, onError: _onApiError);

  XTimelineController controllerFor(XFeedTab tab) => switch (tab) {
    XFeedTab.forYou || XFeedTab.search => forYou,
    XFeedTab.following => following,
    XFeedTab.bookmarks => bookmarks,
  };

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final db = DatabaseService.instance;
    final id = XFeedTool.config.id;
    _hideReposts = await db.getSetting(id, _hideRepostsKey) == 'true';
    _hideReplies = await db.getSetting(id, _hideRepliesKey) == 'true';
    final textScale = double.tryParse(
      await db.getSetting(id, _textScaleKey) ?? '',
    );
    if (textScale != null && textScales.contains(textScale)) {
      _textScale = textScale;
    }
    final startTab = await db.getSetting(id, _startTabKey);
    _startTab = XFeedTab.values.firstWhere(
      (t) => t.name == startTab,
      orElse: () => XFeedTab.forYou,
    );
    _tab = _startTab == XFeedTab.search ? XFeedTab.forYou : _startTab;
    _restoreSeen(await db.getSetting(id, _seenKey));

    final session = await XSessionStore.read();
    if (session == null) {
      _status = XSessionStatus.loggedOut;
    } else {
      _useSession(session);
      _screenName = await XSessionStore.readScreenName();
      _status = XSessionStatus.loggedIn;
      unawaited(_refreshScreenName());
    }
    _notify();
  }

  Future<XTimelinePage> _homeTimeline({
    required bool following,
    String? cursor,
  }) async {
    final seen = _seenPending.toList();
    final page = await _requireApi().homeTimeline(
      following: following,
      cursor: cursor,
      seenPostIds: seen,
    );
    if (seen.isNotEmpty) {
      _seenPending.removeAll(seen);
      _seenSent.addAll(seen);
      _scheduleSeenSave();
    }
    return page;
  }

  /// Buffers posts that were on screen; nothing is sent until the next home
  /// timeline request.
  void markSeen(Iterable<String> postIds) {
    var changed = false;
    for (final id in postIds) {
      if (_seenSent.contains(id) || !_seenPending.add(id)) continue;
      changed = true;
      if (_seenPending.length > _seenBatchLimit) {
        _seenPending.remove(_seenPending.first);
      }
    }
    if (changed) _scheduleSeenSave();
  }

  void _restoreSeen(String? stored) {
    if (stored == null) return;
    try {
      final ids = jsonDecode(stored);
      if (ids is List) markSeen(ids.whereType<String>());
    } on FormatException catch (e) {
      errorLog('[XFeedState] Dropping unreadable seen buffer: $e');
    }
  }

  void _clearSeen() {
    _seenPending.clear();
    _seenSent.clear();
    _saveSeen();
  }

  void _scheduleSeenSave() {
    _seenSave?.cancel();
    _seenSave = Timer(const Duration(seconds: 2), _saveSeen);
  }

  void _saveSeen() {
    _seenSave?.cancel();
    _seenSave = null;
    unawaited(
      DatabaseService.instance.setSetting(
        XFeedTool.config.id,
        _seenKey,
        jsonEncode(_seenPending.toList()),
      ),
    );
  }

  void _useSession(XSession session) {
    _api = XApi(
      session,
      onSessionChanged: (updated) => unawaited(XSessionStore.save(updated)),
    );
  }

  Future<void> _refreshScreenName() async {
    try {
      final name = await _api?.viewerScreenName();
      if (name == null || name == _screenName) return;
      _screenName = name;
      await XSessionStore.saveScreenName(name);
      _notify();
    } on XApiException catch (e) {
      _onApiError(e);
    }
  }

  Future<void> signIn(XSession session) async {
    await XSessionStore.save(session);
    _useSession(session);
    _status = XSessionStatus.loggedIn;
    _sessionExpired = false;
    _screenName = null;
    _engagement.clear();
    _clearSeen();
    for (final t in [forYou, following, bookmarks]) {
      t.reset();
    }
    _notify();
    unawaited(_refreshScreenName());
  }

  Future<void> signOut() async {
    await XSessionStore.clear();
    await XWebConfig.clearCache();
    await WebLogin.clearCookies();
    _api = null;
    _status = XSessionStatus.loggedOut;
    _sessionExpired = false;
    _screenName = null;
    _engagement.clear();
    _clearSeen();
    for (final t in [forYou, following, bookmarks]) {
      t.reset();
    }
    _notify();
  }

  void _onApiError(XApiException e) {
    if (e.kind != XApiErrorKind.unauthorized || _sessionExpired) return;
    _sessionExpired = true;
    _notify();
  }

  Future<void> refreshApiConfig() async {
    await _api?.refreshConfig();
  }

  void setTab(XFeedTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    _notify();
  }

  Future<void> setStartTab(XFeedTab tab) async {
    _startTab = tab;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _startTabKey,
      tab.name,
    );
  }

  Future<void> setHideReposts(bool value) async {
    _hideReposts = value;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _hideRepostsKey,
      '$value',
    );
  }

  Future<void> setHideReplies(bool value) async {
    _hideReplies = value;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _hideRepliesKey,
      '$value',
    );
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _textScaleKey,
      '$value',
    );
  }

  /// Home tabs honour the filters; profiles, searches and threads show all.
  List<XPost> filtered(List<XPost> posts) {
    if (!_hideReposts && !_hideReplies) return posts;
    return [
      for (final p in posts)
        if (!(_hideReposts && p.isRepost) && !(_hideReplies && p.isReply)) p,
    ];
  }

  XEngagement engagementOf(XPost post) =>
      _engagement[post.id] ?? post.engagement;

  Future<bool> toggleLike(XPost post) {
    final current = engagementOf(post);
    final liked = !current.liked;
    return _mutate(
      post,
      current.copyWith(liked: liked, likes: current.likes + (liked ? 1 : -1)),
      () => _requireApi().setLiked(post.id, liked),
    );
  }

  Future<bool> toggleRepost(XPost post) {
    final current = engagementOf(post);
    final reposted = !current.reposted;
    return _mutate(
      post,
      current.copyWith(
        reposted: reposted,
        reposts: current.reposts + (reposted ? 1 : -1),
      ),
      () => _requireApi().setReposted(post.id, reposted),
    );
  }

  Future<bool> toggleBookmark(XPost post) {
    final current = engagementOf(post);
    return _mutate(
      post,
      current.copyWith(bookmarked: !current.bookmarked),
      () => _requireApi().setBookmarked(post.id, !current.bookmarked),
    );
  }

  /// Applies [next] at once and rolls it back if X refuses.
  Future<bool> _mutate(
    XPost post,
    XEngagement next,
    Future<void> Function() request,
  ) async {
    final previous = _engagement[post.id];
    _engagement[post.id] = next;
    _notify();
    try {
      await request();
      return true;
    } on XApiException catch (e) {
      errorLog('[XFeedState] Action on ${post.id} failed: $e');
      if (previous == null) {
        _engagement.remove(post.id);
      } else {
        _engagement[post.id] = previous;
      }
      _onApiError(e);
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_seenSave != null) _saveSeen();
    forYou.dispose();
    following.dispose();
    bookmarks.dispose();
    unawaited(tempScope.cleanTracked());
    super.dispose();
  }
}

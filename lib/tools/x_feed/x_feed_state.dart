import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/web_login/web_login.dart';

import 'api/x_api.dart';
import 'api/x_session.dart';
import 'api/x_web_config.dart';
import 'config.dart';
import 'models/x_post.dart';
import 'x_read_db.dart';
import 'x_timeline_controller.dart';
import 'x_translator.dart';

enum XFeedTab { forYou, following, bookmarks, search }

enum XSessionStatus { unknown, loggedOut, loggedIn }

/// [seen]: marked here, still pending; [sent]: X got it, now or earlier.
enum XReadMark { none, seen, sent }

class XFeedState extends ChangeNotifier {
  static const String _hideRepostsKey = 'hide_reposts';
  static const String _hideRepliesKey = 'hide_replies';
  static const String _startTabKey = 'start_tab';
  static const String _seenKey = 'seen_pending';
  static const String _textScaleKey = 'text_scale';
  static const String _cropPortraitKey = 'crop_portrait';

  /// Only bounds the memory of what was already sent; pending ids never drop.
  static const int _seenSentMemory = 5000;

  /// Like x.com's background polling, pending seen ids go out this long after
  /// the first one, not only with the next page.
  static const Duration _seenFlushDelay = Duration(seconds: 60);

  static const List<double> textScales = [0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

  XSessionStatus _status = XSessionStatus.unknown;
  bool _sessionExpired = false;
  String? _screenName;
  XApi? _api;
  bool _initialized = false;
  bool _disposed = false;

  bool _hideReposts = false;
  bool _hideReplies = false;
  bool _cropPortrait = false;
  double _textScale = 1.0;
  XFeedTab _startTab = XFeedTab.forYou;
  XFeedTab _tab = XFeedTab.forYou;

  final Map<String, XEngagement> _engagement = {};

  /// Posts marked "Not interested" this session; their cards collapse.
  final Set<String> _notInterested = {};

  /// Boosted ids among the loaded posts; the full history stays in [XReadDb].
  final Set<String> _boosted = {};

  late final XTranslator translator = XTranslator(
    () => _api,
    _notify,
    _onApiError,
  );

  /// Downloads for sharing and saving.
  final TempFileScope tempScope = TempFileManager.createScope();

  /// Posts seen since the last home request, oldest first. Like x.com, the
  /// whole set rides along with the next home request and is then cleared.
  final LinkedHashSet<String> _seenPending = LinkedHashSet();

  /// Ids X already got this session, so a post seen again is not resent.
  final LinkedHashSet<String> _seenSent = LinkedHashSet();

  /// Ids riding on a home request still in flight, so a parallel one skips them.
  final Set<String> _seenInFlight = {};
  Timer? _seenSave;
  Timer? _seenFlush;

  /// Read ids among the loaded posts only; the full history stays in [XReadDb].
  final Set<String> _read = {};

  final _Signal _readMarks = _Signal();

  /// Fires on read mark changes only, so the feed does not rebuild for them.
  Listenable get readMarks => _readMarks;

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

  /// Tall single media fill a 4:5 tile instead of showing whole.
  bool get cropPortrait => _cropPortrait;

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
      XTimelineController((cursor) async {
        final page = await fetch(cursor);
        await _loadRead(page.posts);
        return page;
      }, onError: _onApiError);

  XReadMark readMarkOf(XPost post) {
    final ids = post.seenIds;
    if (ids.any(_read.contains)) return XReadMark.sent;
    if (ids.any(_seenPending.contains)) return XReadMark.seen;
    return XReadMark.none;
  }

  Future<void> _loadRead(List<XPost> posts) async {
    await Future.wait([_loadSeenRead(posts), _loadBoosted(posts)]);
  }

  Future<void> _loadBoosted(List<XPost> posts) async {
    try {
      final found = await XReadDb.instance.boostedAmong(
        posts.map((p) => p.id).where((id) => !_boosted.contains(id)),
      );
      if (found.isEmpty) return;
      _boosted.addAll(found);
      _notify();
    } catch (e) {
      errorLog('[XFeedState] Boost lookup failed: $e');
    }
  }

  Future<void> _loadSeenRead(List<XPost> posts) async {
    final ids = {
      for (final p in posts)
        for (final id in p.seenIds)
          if (!_read.contains(id)) id,
    };
    try {
      final found = await XReadDb.instance.readAmong(ids);
      if (found.isEmpty) return;
      _read.addAll(found);
      _readMarks.ping();
    } catch (e) {
      errorLog('[XFeedState] Read lookup failed: $e');
    }
  }

  void _storeRead(List<String> ids) {
    _read.addAll(ids);
    _readMarks.ping();
    XReadDb.instance.markRead(ids).catchError((Object e) {
      errorLog('[XFeedState] Storing read ids failed: $e');
    });
  }

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
    _cropPortrait = await db.getSetting(id, _cropPortraitKey) == 'true';
    final textScale = double.tryParse(
      await db.getSetting(id, _textScaleKey) ?? '',
    );
    if (textScale != null && textScales.contains(textScale)) {
      _textScale = textScale;
    }
    await translator.load();
    final startTab = await db.getSetting(id, _startTabKey);
    _startTab = XFeedTab.values.firstWhere(
      (t) => t.name == startTab,
      orElse: () => XFeedTab.forYou,
    );
    _tab = _startTab == XFeedTab.search ? XFeedTab.forYou : _startTab;
    _restoreSeen(await db.getSetting(id, _seenKey));
    unawaited(_pruneRead());

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
    int count = 20,
  }) async {
    final seen = [
      for (final id in _seenPending)
        if (!_seenInFlight.contains(id)) id,
    ];
    _seenInFlight.addAll(seen);
    final XTimelinePage page;
    try {
      page = await _requireApi().homeTimeline(
        following: following,
        cursor: cursor,
        seenPostIds: seen,
        count: count,
      );
    } finally {
      // On failure the ids stay pending for the next request.
      _seenInFlight.removeAll(seen);
    }
    if (seen.isNotEmpty) {
      _seenPending.removeAll(seen);
      _seenSent.addAll(seen);
      _storeRead(seen);
      while (_seenSent.length > _seenSentMemory) {
        _seenSent.remove(_seenSent.first);
      }
      _scheduleSeenSave();
    }
    return page;
  }

  /// Buffers posts that were on screen or opened; nothing is sent until the
  /// next home timeline request, and nothing is dropped before that.
  void markSeen(Iterable<String> postIds) {
    var changed = false;
    for (final id in postIds) {
      if (!_seenSent.contains(id) && _seenPending.add(id)) changed = true;
    }
    if (!changed) return;
    _scheduleSeenSave();
    _readMarks.ping();
    if (_initialized) _seenFlush ??= Timer(_seenFlushDelay, _flushSeen);
  }

  Future<void> _flushSeen() async {
    _seenFlush = null;
    if (_seenPending.isEmpty || _api == null || _sessionExpired) return;
    try {
      // X takes seen ids only on a home request; the posts are thrown away.
      await _homeTimeline(following: false, count: 1);
    } on XApiException catch (e) {
      debugLog('[XFeedState] Seen flush failed, ids stay pending: $e');
      _onApiError(e);
    }
  }

  void markPostsSeen(Iterable<XPost> posts) =>
      markSeen(posts.expand((p) => p.seenIds));

  /// Stores the pending seen ids now instead of after the save delay, for
  /// when the app is backgrounded and may be killed.
  void persistSeen() {
    if (_seenSave != null) _saveSeen();
  }

  /// The tool closed: pending seen ids are stored, then delivered with one
  /// small home request, and the feeds, translations, downloads and decoded
  /// images are let go. Login, settings and the API config stay.
  Future<void> release() async {
    _seenFlush?.cancel();
    _seenFlush = null;
    _saveSeen();
    for (final t in [forYou, following, bookmarks]) {
      t.reset();
    }
    _engagement.clear();
    _notInterested.clear();
    _boosted.clear();
    _read.clear();
    _readMarks.ping();
    translator.clear();
    PaintingBinding.instance.imageCache.clear();
    await tempScope.cleanTracked();
    if (_seenPending.isEmpty || _api == null || _sessionExpired) return;
    try {
      // X takes seen ids only on a home request; the posts are thrown away.
      await _homeTimeline(following: false, count: 1);
      _saveSeen();
    } on XApiException catch (e) {
      debugLog('[XFeedState] Seen ids stay for the next launch: $e');
    }
  }

  Future<void> _pruneRead() async {
    try {
      final removed = await XReadDb.instance.prune();
      if (removed > 0) debugLog('[XFeedState] Pruned $removed read ids');
    } catch (e) {
      errorLog('[XFeedState] Pruning read ids failed: $e');
    }
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
    _seenFlush?.cancel();
    _seenFlush = null;
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
    translator.onApiCreated();
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
    _notInterested.clear();
    _boosted.clear();
    translator.clear();
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
    _notInterested.clear();
    _boosted.clear();
    translator.clear();
    _clearSeen();
    _read.clear();
    unawaited(
      XReadDb.instance.clear().catchError((Object e) {
        errorLog('[XFeedState] Clearing read ids failed: $e');
      }),
    );
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

  Future<void> setCropPortrait(bool value) async {
    _cropPortrait = value;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _cropPortraitKey,
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

  bool isNotInterested(XPost post) => _notInterested.contains(post.id);

  /// Tells X the post is not of interest, or takes that back.
  Future<bool> setNotInterested(XPost post, bool value) async {
    final feedback = post.notInterested;
    if (feedback == null || isNotInterested(post) == value) return true;
    void apply(bool on) =>
        on ? _notInterested.add(post.id) : _notInterested.remove(post.id);
    apply(value);
    _notify();
    try {
      await _requireApi().sendFeedback(feedback, undo: !value);
      return true;
    } on XApiException catch (e) {
      errorLog('[XFeedState] Feedback on ${post.id} failed: $e');
      apply(!value);
      _onApiError(e);
      _notify();
      return false;
    }
  }

  bool isBoosted(XPost post) => _boosted.contains(post.id);

  /// Reports the post as shared by link, a signal X's ranking learns from.
  /// X gives no state back, so the mark is kept locally; there is no undo.
  Future<bool> boost(XPost post) async {
    if (!_boosted.add(post.id)) return true;
    _notify();
    try {
      await _requireApi().sendShareSignal(post);
    } on XApiException catch (e) {
      errorLog('[XFeedState] Boost of ${post.id} failed: $e');
      _boosted.remove(post.id);
      _onApiError(e);
      _notify();
      return false;
    }
    try {
      await XReadDb.instance.markBoosted(post.id);
    } catch (e) {
      errorLog('[XFeedState] Storing boost of ${post.id} failed: $e');
    }
    return true;
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
    _seenFlush?.cancel();
    if (_seenSave != null) _saveSeen();
    forYou.dispose();
    following.dispose();
    bookmarks.dispose();
    _readMarks.dispose();
    unawaited(tempScope.cleanTracked());
    super.dispose();
  }
}

class _Signal extends ChangeNotifier {
  bool _queued = false;

  /// A ping mid-frame (from a scroll notification during layout) would mark
  /// widgets dirty after the build phase with no new frame scheduled.
  void ping() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_queued) return;
    _queued = true;
    scheduler.addPostFrameCallback((_) {
      _queued = false;
      notifyListeners();
    });
    scheduler.scheduleFrame();
  }
}

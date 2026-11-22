import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/video_player/video_backend.dart';

import 'config.dart';
import 'models/x_watched_video.dart';
import 'x_video_history_db.dart';

enum XHistoryPeriod { today, week, month, year, older }

class XHistoryGroup {
  final XHistoryPeriod period;
  final List<XWatchedVideo> entries;

  const XHistoryGroup(this.period, this.entries);

  int get plays => entries.fold(0, (sum, e) => sum + e.playCount);

  Duration get watched =>
      entries.fold(Duration.zero, (sum, e) => sum + e.watched);

  /// The account with the most entries, when one stands out.
  String? get topAuthor {
    if (entries.length < 3) return null;
    final counts = <String, int>{};
    for (final e in entries) {
      counts.update(e.authorScreenName, (c) => c + 1, ifAbsent: () => 1);
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.value > 1 ? top.key : null;
  }
}

/// The watched-video history: the view threshold setting, the entries while
/// the history tab is open, and the recording of plays.
class XVideoHistory extends ChangeNotifier {
  static const String _thresholdKey = 'history_threshold_s';
  static const List<int> thresholdOptions = [3, 5, 10, 15, 30, 60];

  /// For "clear older than"; null clears everything.
  static const List<Duration?> clearOptions = [
    Duration(days: 7),
    Duration(days: 30),
    Duration(days: 90),
    Duration(days: 365),
    null,
  ];

  int _thresholdSeconds = 5;
  List<XWatchedVideo>? _entries;
  bool _loading = false;
  bool _disposed = false;

  int get thresholdSeconds => _thresholdSeconds;

  /// Null until [ensureLoaded] finished.
  List<XWatchedVideo>? get entries => _entries;

  /// The setting, or half of a shorter video.
  Duration thresholdFor(Duration duration) {
    final setting = Duration(seconds: _thresholdSeconds);
    final half = duration ~/ 2;
    return half < setting ? half : setting;
  }

  Future<void> loadSettings() async {
    final stored = int.tryParse(
      await DatabaseService.instance.getSetting(
            XFeedTool.config.id,
            _thresholdKey,
          ) ??
          '',
    );
    if (stored != null && thresholdOptions.contains(stored)) {
      _thresholdSeconds = stored;
    }
  }

  Future<void> setThreshold(int seconds) async {
    _thresholdSeconds = seconds;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _thresholdKey,
      '$seconds',
    );
  }

  Future<void> ensureLoaded() async {
    if (_entries != null || _loading) return;
    await _reload();
  }

  Future<void> _reload() async {
    _loading = true;
    try {
      _entries = await XVideoHistoryDb.instance.entries();
    } catch (e) {
      errorLog('[XVideoHistory] Loading failed: $e');
      _entries ??= const [];
    } finally {
      _loading = false;
    }
    _notify();
  }

  /// Drops the loaded entries; the next [ensureLoaded] reads them again.
  void release() {
    _entries = null;
    _notify();
  }

  Future<void> prune() async {
    try {
      final removed = await XVideoHistoryDb.instance.prune();
      if (removed > 0) debugLog('[XVideoHistory] Pruned $removed entries');
    } catch (e) {
      errorLog('[XVideoHistory] Pruning failed: $e');
    }
  }

  Future<void> remove(XWatchedVideo entry) async {
    _entries = _entries?.where((e) => !_same(e, entry)).toList();
    _notify();
    try {
      await XVideoHistoryDb.instance.remove(entry);
    } catch (e) {
      errorLog('[XVideoHistory] Removing failed: $e');
    }
  }

  /// Puts a removed entry back as it was.
  Future<void> restore(XWatchedVideo entry) async {
    try {
      await XVideoHistoryDb.instance.restore(entry);
    } catch (e) {
      errorLog('[XVideoHistory] Restoring failed: $e');
    }
    if (_entries != null) await _reload();
  }

  /// Returns how many entries were removed.
  Future<int> clearOlderThan(Duration? age) async {
    var removed = 0;
    try {
      removed = await XVideoHistoryDb.instance.clearOlderThan(age);
    } catch (e) {
      errorLog('[XVideoHistory] Clearing failed: $e');
    }
    if (_entries != null) await _reload();
    return removed;
  }

  /// Tracks one player session over [videos], keyed by their source.
  XVideoWatch watch(Map<Uri, XWatchedVideo> videos) =>
      XVideoWatch(this, videos);

  Future<void> _record(
    XWatchedVideo video, {
    required Duration duration,
    required Duration played,
    required bool newPlay,
  }) async {
    try {
      await XVideoHistoryDb.instance.record(
        video,
        duration: duration,
        played: played,
        newPlay: newPlay,
      );
    } catch (e) {
      errorLog('[XVideoHistory] Recording ${video.postId} failed: $e');
      return;
    }
    if (_entries != null) await _reload();
  }

  static List<XHistoryGroup> group(
    List<XWatchedVideo> entries, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    XHistoryPeriod periodOf(DateTime time) {
      if (!time.isBefore(today)) return XHistoryPeriod.today;
      final age = today.difference(time);
      if (age < const Duration(days: 7)) return XHistoryPeriod.week;
      if (age < const Duration(days: 30)) return XHistoryPeriod.month;
      if (age < const Duration(days: 365)) return XHistoryPeriod.year;
      return XHistoryPeriod.older;
    }

    final byPeriod = <XHistoryPeriod, List<XWatchedVideo>>{};
    for (final e in entries) {
      byPeriod.putIfAbsent(periodOf(e.lastWatchedAt), () => []).add(e);
    }
    return [
      for (final period in XHistoryPeriod.values)
        if (byPeriod[period] case final list?) XHistoryGroup(period, list),
    ];
  }

  static bool _same(XWatchedVideo a, XWatchedVideo b) =>
      a.postId == b.postId && a.mediaIndex == b.mediaIndex;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Sums the time a video actually played; seeks and loops do not count.
/// The entry is written once the threshold is reached and topped up on
/// [close], so a session costs at most two writes per video.
class XVideoWatch {
  /// Larger position steps are seeks, not playback.
  static const Duration _maxStep = Duration(seconds: 2);

  final XVideoHistory _history;
  final Map<Uri, XWatchedVideo> _videos;
  final Map<Uri, _Track> _tracks = {};

  XVideoWatch(this._history, this._videos);

  void onProgress(Uri source, VideoPlaybackState state) {
    final video = _videos[source];
    if (video == null || !state.initialized) return;
    if (state.duration <= Duration.zero) return;
    final track = _tracks.putIfAbsent(source, _Track.new);
    final step = state.position - track.position;
    track.position = state.position;
    track.duration = state.duration;
    if (state.playing && step > Duration.zero && step <= _maxStep) {
      track.played += step;
      track.unsaved += step;
    }
    if (track.recorded ||
        track.played < _history.thresholdFor(state.duration)) {
      return;
    }
    track.recorded = true;
    unawaited(_flush(video, track, newPlay: true));
  }

  void close() {
    _tracks.forEach((source, track) {
      if (track.recorded && track.unsaved > Duration.zero) {
        unawaited(_flush(_videos[source]!, track, newPlay: false));
      }
    });
  }

  Future<void> _flush(
    XWatchedVideo video,
    _Track track, {
    required bool newPlay,
  }) {
    final played = track.unsaved;
    track.unsaved = Duration.zero;
    return _history._record(
      video,
      duration: track.duration,
      played: played,
      newPlay: newPlay,
    );
  }
}

class _Track {
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration played = Duration.zero;
  Duration unsaved = Duration.zero;
  bool recorded = false;
}

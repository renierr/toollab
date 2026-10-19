import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';

import '../health_dashboard/store/health_schema.dart';
import '../health_dashboard/store/health_store.dart';
import 'audio/sleep_chunk_analyzer.dart';
import 'sleep_player.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

class SleepStageBand {
  const SleepStageBand({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// Backs the sleep sessions page: the session list plus per-session
/// selection, category filter and Health sleep bands. Audio lives in
/// [SleepPlayer]; this state only steers it.
class SleepSessionsState extends ChangeNotifier {
  SleepSessionsState(this._player) {
    _player.onChunkStarted = _onChunkStarted;
    SleepSessionStore.revision.addListener(_onStoreChanged);
    SleepSessionStore.analysisProgress.addListener(notifyListeners);
    load();
  }

  static const _logPrefix = '[SleepSessions]';

  /// A sync pull bumps the store once per chunk; coalesce into one reload.
  static const _reloadDebounce = Duration(milliseconds: 400);

  final SleepPlayer _player;
  List<SleepSession> _sessions = const [];
  bool _loading = true;
  bool _disposed = false;
  Timer? _reloadTimer;
  final Map<String, int> _selected = {};
  final Map<String, Set<SleepSoundCategory?>> _filters = {};
  final Map<String, List<SleepStageBand>> _healthStages = {};
  final Set<String> _healthLoading = {};

  List<SleepSession> get sessions => _sessions;
  bool get loading => _loading;

  double? analysisProgress(String id) =>
      SleepSessionStore.analysisProgress.value[id];

  List<SleepStageBand> healthStages(String id) => _healthStages[id] ?? const [];
  bool healthLoading(String id) => _healthLoading.contains(id);

  Future<void> load() async {
    final list = await SleepSessionStore.list();
    if (_disposed) return;
    _sessions = list;
    _loading = false;
    for (final s in list) {
      _player.updateSession(s);
    }
    notifyListeners();
  }

  void _onStoreChanged() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(_reloadDebounce, () => unawaited(load()));
  }

  void _onChunkStarted(String sessionId, int index) {
    _selected[sessionId] = index;
    notifyListeners();
  }

  // --- Selection & filter ---

  int? selectedIndex(String id) => _selected[id];

  void select(SleepSession session, int index) {
    if (index < 0 || index >= session.data.events.length) return;
    if (_player.isQueueActive(session.id)) {
      if (!_player.jumpTo(index)) unawaited(playAll(session, from: index));
      return;
    }
    if (_selected[session.id] == index) return;
    _selected[session.id] = index;
    notifyListeners();
  }

  void step(SleepSession session, int delta) {
    final visible = visibleIndices(session);
    if (visible.isEmpty) return;
    final current = _selected[session.id];
    final pos = current == null ? -1 : visible.indexOf(current);
    final next = pos < 0
        ? (delta > 0 ? 0 : visible.length - 1)
        : (pos + delta).clamp(0, visible.length - 1);
    select(session, visible[next]);
  }

  Set<SleepSoundCategory?> filter(String id) => _filters[id] ?? const {};

  void toggleFilter(String id, SleepSoundCategory? category) {
    final set = {...filter(id)};
    if (!set.remove(category)) set.add(category);
    _filters[id] = set;
    notifyListeners();
  }

  void clearFilter(String id) {
    _filters.remove(id);
    notifyListeners();
  }

  List<int> visibleIndices(SleepSession session) {
    final f = filter(session.id);
    final events = session.data.events;
    return [
      for (var i = 0; i < events.length; i++)
        if (f.isEmpty || f.contains(events[i].analysis?.category)) i,
    ];
  }

  Future<void> playAll(SleepSession session, {int? from}) async {
    final queue = visibleIndices(session);
    if (queue.isEmpty) return;
    final start = from == null ? 0 : queue.indexWhere((i) => i >= from);
    await _player.play(session, queue, startPos: start < 0 ? 0 : start);
  }

  // --- Edits ---

  Future<void> annotate(SleepSession session, SleepEvent event, String text) =>
      SleepSessionStore.update(session.path, (data) {
        for (final e in data.events) {
          if (e.fileName == event.fileName) {
            e.annotation = text.trim().isEmpty ? null : text.trim();
          }
        }
      });

  Future<void> analyze(SleepSession session) =>
      SleepSessionStore.analyze(session);

  Future<void> delete(SleepSession session) async {
    if (_player.sessionId == session.id) await _player.stop();
    _selected.remove(session.id);
    _filters.remove(session.id);
    await SleepSessionStore.delete(session);
  }

  /// Returns whether any sleep stage was found.
  Future<bool> loadHealthStages(SleepSession session) async {
    _healthLoading.add(session.id);
    notifyListeners();
    final start = session.data.startedAt;
    final end = session.data.endedAt;
    final bands = <SleepStageBand>[];
    // Prefer the already-synced Health Dashboard store (no extra permissions).
    try {
      final sessions = await HealthStore.instance.sessions(
        kind: HealthSchema.sessionKindSleep,
        from: start.millisecondsSinceEpoch,
        to: end.millisecondsSinceEpoch,
      );
      for (final s in sessions) {
        bands.add(
          SleepStageBand(
            start: DateTime.fromMillisecondsSinceEpoch(s.t0),
            end: DateTime.fromMillisecondsSinceEpoch(s.t1),
          ),
        );
      }
    } catch (e) {
      errorLog('$_logPrefix health store: $e');
    }
    if (bands.isEmpty && Platform.isAndroid) {
      try {
        final connector = await hc.HealthConnector.create();
        await connector.requestPermissions([
          hc.HealthDataType.sleepSession.readPermission,
        ]);
        final req = hc.HealthDataType.sleepSession.readInTimeRange(
          startTime: start,
          endTime: end,
        );
        final resp = await connector.readRecords(req);
        for (final r in (resp.records as List).cast<hc.HealthRecord>()) {
          if (r is hc.IntervalHealthRecord) {
            bands.add(SleepStageBand(start: r.startTime, end: r.endTime));
          }
        }
      } catch (e) {
        errorLog('$_logPrefix health connect: $e');
      }
    }
    if (_disposed) return bands.isNotEmpty;
    _healthStages[session.id] = bands;
    _healthLoading.remove(session.id);
    notifyListeners();
    return bands.isNotEmpty;
  }

  @override
  void dispose() {
    _disposed = true;
    _reloadTimer?.cancel();
    _player.onChunkStarted = null;
    SleepSessionStore.revision.removeListener(_onStoreChanged);
    SleepSessionStore.analysisProgress.removeListener(notifyListeners);
    super.dispose();
  }
}

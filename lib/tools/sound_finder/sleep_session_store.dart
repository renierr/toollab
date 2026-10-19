import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'audio/sleep_chunk_analyzer.dart';
import 'sleep_session_data.dart';

/// One session directory on disk plus what it occupies.
class SleepSession {
  SleepSession({
    required this.data,
    required this.fileSizes,
    required this.jsonBytes,
    this.synthetic = false,
  });

  final SleepSessionData data;

  /// Bytes per WAV file present on disk, keyed by file name.
  final Map<String, int> fileSizes;
  final int jsonBytes;

  /// Rebuilt from chunk names because no session.json exists (legacy or an
  /// interrupted recording). Never synced until saved once.
  final bool synthetic;

  String get path => data.path;
  String get id => data.id;
  DateTime get startedAt => data.startedAt;
  int get wavBytes => fileSizes.values.fold(0, (a, b) => a + b);
  int get totalBytes => wavBytes + jsonBytes;
  bool hasFile(SleepEvent e) => fileSizes.containsKey(e.fileName);
  int? sizeOf(SleepEvent e) => fileSizes[e.fileName];
}

/// File-backed storage for sleep sessions: one directory per session holding
/// `session.json` and the kept WAV chunks.
class SleepSessionStore {
  SleepSessionStore._();

  static const _logPrefix = '[SleepSessionStore]';
  static const _tombstoneFile = 'sync_tombstones.json';

  /// Bumped whenever sessions change on disk, so open views can reload.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Analysis progress (0..1) per session id while a run is in flight.
  static final ValueNotifier<Map<String, double>> analysisProgress =
      ValueNotifier(const {});

  static final Map<String, Future<void>> _locks = {};
  static String? _rootPath;

  static void notifyChanged() => revision.value++;

  static Future<Directory> root() async {
    if (_rootPath == null) {
      final base = await getApplicationDocumentsDirectory();
      _rootPath = '${base.path}/sleep_recordings';
    }
    final dir = Directory(_rootPath!);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> sessionPath(String id) async =>
      '${(await root()).path}/$id';

  static Future<List<SleepSession>> list() async {
    final rootDir = await root();
    await _migrateLooseChunks(rootDir);
    final dirs = await rootDir.list().where((e) => e is Directory).toList();
    final sessions = (await Future.wait(
      dirs.map((d) => _read(d as Directory)),
    )).nonNulls.toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  static Future<SleepSession?> byId(String id) async {
    final dir = Directory(await sessionPath(id));
    if (!await dir.exists()) return null;
    return _read(dir);
  }

  static Future<SleepSession?> _read(Directory dir) async {
    final sizes = <String, int>{};
    await for (final f in dir.list()) {
      if (f is File && f.path.toLowerCase().endsWith('.wav')) {
        sizes[f.uri.pathSegments.last] = await f.length();
      }
    }
    final data = await SleepSessionData.load(dir.path);
    if (data != null) {
      final json = File('${dir.path}/session.json');
      return SleepSession(
        data: data,
        fileSizes: sizes,
        jsonBytes: await json.length(),
      );
    }
    if (sizes.isEmpty) return null;
    return SleepSession(
      data: _synthesize(dir.path, sizes.keys.toList()..sort()),
      fileSizes: sizes,
      jsonBytes: 0,
      synthetic: true,
    );
  }

  /// Loads fresh from disk, applies [mutate] and saves, serialized per session
  /// so a background analysis and a UI edit never overwrite each other.
  static Future<SleepSessionData?> update(
    String path,
    void Function(SleepSessionData data) mutate,
  ) async {
    SleepSessionData? result;
    await _serialized(path, () async {
      final dir = Directory(path);
      if (!await dir.exists()) return;
      final data =
          await SleepSessionData.load(path) ?? (await _read(dir))?.data;
      if (data == null) return;
      mutate(data);
      await data.save();
      result = data;
    });
    if (result != null) notifyChanged();
    return result;
  }

  /// Writes a session as-is, keeping its [SleepSessionData.updatedAt].
  static Future<void> replace(SleepSessionData data) async {
    await _serialized(data.path, () => data.save(touch: false));
    notifyChanged();
  }

  static Future<void> _serialized(String key, Future<void> Function() body) {
    final previous = _locks[key] ?? Future<void>.value();
    final next = previous.then((_) => body()).catchError((Object e) {
      errorLog('$_logPrefix $key: $e');
    });
    _locks[key] = next;
    return next.whenComplete(() {
      if (identical(_locks[key], next)) _locks.remove(key);
    });
  }

  /// Classifies every chunk off the UI isolate. Skips a session that is
  /// already being analyzed.
  static Future<void> analyze(SleepSession session) async {
    final id = session.id;
    if (analysisProgress.value.containsKey(id)) return;
    _setProgress(id, 0);
    try {
      final events = session.data.events;
      final results = <String, SleepChunkAnalysis>{};
      for (var i = 0; i < events.length; i++) {
        final path = session.data.fileFor(events[i]).path;
        try {
          final r = await Isolate.run(
            () => SleepChunkAnalyzer.analyzeFile(path),
          );
          if (r != null) results[events[i].fileName] = r;
        } catch (e) {
          errorLog('$_logPrefix analyze ${events[i].fileName}: $e');
        }
        _setProgress(id, (i + 1) / events.length);
      }
      await update(session.path, (data) {
        for (final e in data.events) {
          e.analysis = results[e.fileName] ?? e.analysis;
        }
        data.analysisVersion = SleepChunkAnalyzer.version;
      });
    } finally {
      final next = Map.of(analysisProgress.value)..remove(id);
      analysisProgress.value = next;
    }
  }

  static void _setProgress(String id, double v) {
    analysisProgress.value = {...analysisProgress.value, id: v};
  }

  /// Removes the session and leaves tombstones so sync deletes it elsewhere.
  static Future<void> delete(SleepSession session) async {
    if (!session.synthetic) {
      await addTombstones([
        session.id,
        for (final e in session.data.events)
          chunkSyncId(session.id, e.fileName),
      ]);
    }
    final dir = Directory(session.path);
    if (await dir.exists()) await dir.delete(recursive: true);
    notifyChanged();
  }

  // --- Sync record ids: a session is `<dir>`, a chunk `<dir>:<file>`. ---

  static String chunkSyncId(String sessionId, String fileName) =>
      '$sessionId:$fileName';

  /// Splits a sync id into session id and chunk file (null for a session).
  static (String, String?) parseSyncId(String id) {
    final i = id.indexOf(':');
    if (i < 0) return (id, null);
    return (id.substring(0, i), id.substring(i + 1));
  }

  static Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> deleteDir(String path) async {
    final d = Directory(path);
    if (await d.exists()) await d.delete(recursive: true);
  }

  // --- Sync tombstones: id -> deletion time in epoch ms. ---

  static Future<File> _tombstones() async =>
      File('${(await root()).path}/$_tombstoneFile');

  static Future<Map<String, int>> tombstones() async {
    final f = await _tombstones();
    if (!await f.exists()) return {};
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> addTombstones(List<String> ids) async {
    if (ids.isEmpty) return;
    await _serialized(_tombstoneFile, () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final map = await tombstones();
      for (final id in ids) {
        map[id] = now;
      }
      await (await _tombstones()).writeAsString(jsonEncode(map));
    });
  }

  static Future<void> removeTombstone(String id) async {
    await _serialized(_tombstoneFile, () async {
      final map = await tombstones();
      if (map.remove(id) == null) return;
      await (await _tombstones()).writeAsString(jsonEncode(map));
    });
  }

  static Future<void> _migrateLooseChunks(Directory rootDir) async {
    final loose = await rootDir
        .list()
        .where((f) => f is File && f.path.toLowerCase().endsWith('.wav'))
        .cast<File>()
        .toList();
    if (loose.isEmpty) return;
    final legacy = Directory('${rootDir.path}/session-legacy');
    if (!await legacy.exists()) await legacy.create(recursive: true);
    for (final f in loose) {
      final target = File('${legacy.path}/${f.uri.pathSegments.last}');
      try {
        if (await target.exists()) {
          await f.delete();
        } else {
          await f.rename(target.path);
        }
      } catch (_) {}
    }
  }

  static final _chunkStamp = RegExp(r'chunk-(\d{8})-(\d{6})');
  static final _sessionStamp = RegExp(r'session-(\d{8})-(\d{6})');

  static DateTime? _parseStamp(RegExp re, String name) {
    final m = re.firstMatch(name);
    if (m == null) return null;
    final d = m.group(1)!;
    final t = m.group(2)!;
    return DateTime(
      int.parse(d.substring(0, 4)),
      int.parse(d.substring(4, 6)),
      int.parse(d.substring(6, 8)),
      int.parse(t.substring(0, 2)),
      int.parse(t.substring(2, 4)),
      int.parse(t.substring(4, 6)),
    );
  }

  static SleepSessionData _synthesize(String path, List<String> files) {
    const chunk = Duration(seconds: 15);
    final sessionStart =
        _parseStamp(_sessionStamp, path.split(RegExp(r'[\\/]')).last) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    // Chunk names carry the time the chunk was written, i.e. its end.
    final events = [
      for (final name in files)
        () {
          final end = _parseStamp(_chunkStamp, name) ?? sessionStart.add(chunk);
          return SleepEvent(
            fileName: name,
            startedAt: end.subtract(chunk),
            endedAt: end,
            peakAmplitude: 0.03,
            classification: 'unknown',
          );
        }(),
    ];
    final start = events.isEmpty ? sessionStart : events.first.startedAt;
    final end = events.isEmpty ? start : events.last.endedAt;
    return SleepSessionData(
      path: path,
      startedAt: start,
      endedAt: end.isAfter(start) ? end : start.add(const Duration(minutes: 1)),
      targetMinutes: 0,
      threshold: 0.005,
      adaptiveThreshold: false,
      events: events,
    );
  }
}

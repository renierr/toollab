import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/wav_decoder.dart';
import 'package:tool_lab/services/database_service.dart';

import 'audio/sleep_chunk_analyzer.dart';
import 'audio/sleep_wav_compressor.dart';
import 'config.dart';
import 'sleep_session_data.dart';

/// One session directory on disk plus what it occupies.
class SleepSession {
  SleepSession({
    required this.data,
    required this.fileSizes,
    required this.jsonBytes,
    this.synthetic = false,
    this.offloaded = const {},
  });

  final SleepSessionData data;

  /// Bytes per audio file present on disk, keyed by file name.
  final Map<String, int> fileSizes;
  final int jsonBytes;

  /// Chunks kept on the server only: sync file name -> server version.
  final Map<String, int> offloaded;

  /// Rebuilt from chunk names because no session.json exists (legacy or an
  /// interrupted recording). Never synced until saved once.
  final bool synthetic;

  String get path => data.path;
  String get id => data.id;
  DateTime get startedAt => data.startedAt;
  int get audioBytes => fileSizes.values.fold(0, (a, b) => a + b);
  int get totalBytes => audioBytes + jsonBytes;
  bool hasFile(SleepEvent e) =>
      fileSizes.containsKey(e.fileName) ||
      fileSizes.containsKey(e.syncFileName);
  int? sizeOf(SleepEvent e) =>
      fileSizes[e.fileName] ?? fileSizes[e.syncFileName];
  bool isOffloaded(SleepEvent e) =>
      !hasFile(e) && offloaded.containsKey(e.syncFileName);
  int get offloadedCount => data.events.where(isOffloaded).length;
}

/// File-backed storage for sleep sessions: one directory per session holding
/// `session.json` and the kept audio chunks.
class SleepSessionStore {
  SleepSessionStore._();

  static const _logPrefix = '[SleepSessionStore]';
  static const _tombstoneFile = 'sync_tombstones.json';

  /// Bumped whenever sessions change on disk, so open views can reload.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Analysis progress (0..1) per session id while a run is in flight.
  static final ValueNotifier<Map<String, double>> analysisProgress =
      ValueNotifier(const {});
  static final ValueNotifier<Map<String, double>> compressionProgress =
      ValueNotifier(const {});

  static final Map<String, Future<void>> _locks = {};
  static String? _rootPath;

  @visibleForTesting
  static void overrideRootForTest(String? path) => _rootPath = path;

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
      if (f is File &&
          (f.path.toLowerCase().endsWith('.wav') ||
              f.path.toLowerCase().endsWith('.flac'))) {
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
        offloaded: await _readOffloaded(dir.path),
      );
    }
    if (sizes.isEmpty) return null;
    final files = sizes.keys.toList()..sort();
    final durations = <String, Duration>{};
    for (final name in files) {
      final duration = await _audioDuration(File('${dir.path}/$name'));
      if (duration != null) durations[name] = duration;
    }
    return SleepSession(
      data: _synthesize(dir.path, files, durations),
      fileSizes: sizes,
      jsonBytes: 0,
      synthetic: true,
    );
  }

  /// Chunk length from its header, so sessions rebuilt from file names keep
  /// their real timing after the chunk length became configurable.
  static Future<Duration?> _audioDuration(File file) async {
    try {
      final handle = await file.open();
      try {
        final header = await handle.read(4096);
        double? seconds;
        if (file.path.toLowerCase().endsWith('.flac') && header.length >= 26) {
          final info = ByteData.sublistView(header).getUint64(18, Endian.big);
          final rate = info >> 44;
          final samples = info & 0xfffffffff;
          if (rate > 0 && samples > 0) seconds = samples / rate;
        } else {
          seconds = WavDecoder.durationSeconds(header);
        }
        if (seconds == null) return null;
        return Duration(milliseconds: (seconds * 1000).round());
      } finally {
        await handle.close();
      }
    } catch (e) {
      errorLog('$_logPrefix wav duration ${file.path}: $e');
      return null;
    }
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

  /// Stores the server's version of a pulled chunk in its event, so the chunk
  /// reports that version next sync instead of being pulled again.
  static Future<void> adoptPulledChunk(
    String path, {
    required String syncFile,
    required String fileName,
    required int updatedAt,
  }) => _serialized(path, () async {
    final data = await SleepSessionData.load(path);
    final event = data?.events
        .where((e) => e.syncFileName == syncFile)
        .firstOrNull;
    if (data == null ||
        event == null ||
        (event.fileName == fileName &&
            event.syncFileName == syncFile &&
            event.audioUpdatedAt == updatedAt)) {
      return;
    }
    if (event.fileName != fileName) {
      event.replaceAudio(fileName, updatedAt);
    } else {
      event.audioUpdatedAt = updatedAt;
    }
    if (event.syncFileName != syncFile) event.storedSyncFile = syncFile;
    await data.save(touch: false);
  });

  /// Drops the offload entry of a chunk whose audio is local again.
  static Future<void> forgetOffloaded(String path, String syncFile) =>
      _serialized(path, () async {
        final map = await _readOffloaded(path);
        if (map.remove(syncFile) != null) await _writeOffloaded(path, map);
      });

  // --- Offload: old sessions keep their audio on the server only. ---

  static const _offloadedFile = 'offloaded.json';
  static const _kKeepDays = 'sf_sleep_keep_days';
  static const defaultKeepDays = 30;

  /// 0 keeps audio forever.
  static const keepDaysOptions = [7, 14, 30, 90, 0];

  static Future<int> keepDays() async {
    final raw = await DatabaseService.instance.getSetting(
      SoundFinderTool.config.id,
      _kKeepDays,
    );
    final days = int.tryParse(raw ?? '');
    return days != null && keepDaysOptions.contains(days)
        ? days
        : defaultKeepDays;
  }

  static Future<void> setKeepDays(int days) => DatabaseService.instance
      .setSetting(SoundFinderTool.config.id, _kKeepDays, days.toString());

  /// Falls back to the stamp in the session id when no session.json is local.
  static bool isOld(String sessionId, DateTime? startedAt, int keepDays) {
    if (keepDays <= 0) return false;
    final start = startedAt ?? _parseStamp(_sessionStamp, sessionId);
    return start != null &&
        start.isBefore(DateTime.now().subtract(Duration(days: keepDays)));
  }

  static Future<Map<String, int>> _readOffloaded(String path) async {
    final f = File('$path/$_offloadedFile');
    if (!await f.exists()) return {};
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      errorLog('$_logPrefix offloaded $path: $e');
      return {};
    }
  }

  static Future<void> _writeOffloaded(String path, Map<String, int> map) async {
    final f = File('$path/$_offloadedFile');
    if (map.isEmpty) {
      if (await f.exists()) await f.delete();
      return;
    }
    await f.writeAsString(jsonEncode(map));
  }

  /// Records [versions] (sync file name -> server version) as kept on the
  /// server and deletes the local audio. Returns the sync file names handled.
  static Future<Set<String>> offload(
    String path,
    Map<String, int> versions,
  ) async {
    final done = <String>{};
    final id = path.split(RegExp(r'[\\/]')).last;
    if (versions.isEmpty ||
        analysisProgress.value.containsKey(id) ||
        compressionProgress.value.containsKey(id)) {
      return done;
    }
    await _serialized(path, () async {
      final data = await SleepSessionData.load(path);
      // Without a local session.json (first sync of an old session) every
      // chunk is taken as named; its session record arrives in the same sync.
      final files = <String, String>{
        if (data == null)
          for (final f in versions.keys) f: f
        else
          for (final e in data.events)
            if (versions.containsKey(e.syncFileName))
              e.syncFileName: e.fileName,
      };
      if (files.isEmpty) return;
      final map = await _readOffloaded(path);
      for (final f in files.keys) {
        map[f] = versions[f]!;
      }
      // The entries go first: a crash before the deletes leaves a harmless
      // extra file, the reverse would make sync pull the audio straight back.
      await Directory(path).create(recursive: true);
      await _writeOffloaded(path, map);
      for (final MapEntry(key: syncFile, value: fileName) in files.entries) {
        await deleteFile('$path/$fileName');
        if (syncFile != fileName) await deleteFile('$path/$syncFile');
        done.add(syncFile);
      }
    });
    if (done.isNotEmpty) notifyChanged();
    return done;
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

  /// Classifies every chunk off the UI isolate, in batches, with the session's
  /// quiet-room floor as a prior. Skips a session already being analyzed.
  static Future<void> analyze(SleepSession session) async {
    final id = session.id;
    if (analysisProgress.value.containsKey(id)) return;
    _setProgress(id, 0);
    try {
      final events = session.data.events;
      final results = <String, SleepChunkAnalysis>{};
      final noiseFloorDb = session.data.noiseFloorDb;
      const batchSize = 8;
      for (var start = 0; start < events.length; start += batchSize) {
        final end = math.min(start + batchSize, events.length);
        final slice = events.sublist(start, end);
        final paths = [for (final e in slice) session.data.fileFor(e).path];
        final names = [for (final e in slice) e.fileName];
        try {
          final batch = await Isolate.run(() {
            final out = <String, SleepChunkAnalysis>{};
            for (var i = 0; i < paths.length; i++) {
              final analysis = SleepChunkAnalyzer.analyzeFile(
                paths[i],
                noiseFloorDb: noiseFloorDb,
              );
              if (analysis != null) out[names[i]] = analysis;
            }
            return out;
          });
          results.addAll(batch);
        } catch (e) {
          errorLog('$_logPrefix analyze batch $start-$end: $e');
        }
        _setProgress(id, end / events.length);
      }
      await update(session.path, (data) {
        for (final e in data.events) {
          final r = results[e.fileName];
          if (r == null) continue;
          e.analysis = r;
          if (r.peakAmplitude > 0) e.peakAmplitude = r.peakAmplitude;
        }
        data.analysisVersion =
            data.events.every((event) => results.containsKey(event.fileName))
            ? SleepChunkAnalyzer.version
            : 0;
      });
    } finally {
      final next = Map.of(analysisProgress.value)..remove(id);
      analysisProgress.value = next;
    }
  }

  static void _setProgress(String id, double v) {
    analysisProgress.value = {...analysisProgress.value, id: v};
  }

  static Future<int> compress(SleepSession session) async {
    final id = session.id;
    if (compressionProgress.value.containsKey(id) || session.synthetic) {
      return 0;
    }
    final events = session.data.events
        .where((e) => e.fileName.endsWith('.wav') && session.hasFile(e))
        .toList();
    if (events.isEmpty) return 0;
    compressionProgress.value = {...compressionProgress.value, id: 0};
    final scope = TempFileManager.createScope();
    var converted = 0;
    try {
      final staged = await scope.createFile(
        'sleep-compress-${DateTime.now().microsecondsSinceEpoch}.flac',
      );
      for (var i = 0; i < events.length; i++) {
        final event = events[i];
        final original = '${session.path}/${event.fileName}';
        final nextName =
            '${event.fileName.substring(0, event.fileName.length - 4)}.flac';
        final target = File('${session.path}/$nextName');
        try {
          final alreadyExists = await target.exists();
          final valid = alreadyExists
              ? await target.length() < await File(original).length() &&
                    await Isolate.run(
                      () => sleepWavMatchesFlac((original, target.path)),
                    )
              : await Isolate.run(() => compressSleepWav((original, staged)));
          if (valid) {
            var committed = false;
            await _serialized(session.path, () async {
              final current = await SleepSessionData.load(session.path);
              final currentEvent = current?.events
                  .where((e) => e.fileName == event.fileName)
                  .firstOrNull;
              if (current == null ||
                  currentEvent == null ||
                  !await File(original).exists()) {
                return;
              }
              if (await target.exists()) {
                if (!await Isolate.run(
                  () => sleepWavMatchesFlac((original, target.path)),
                )) {
                  return;
                }
              } else {
                if (alreadyExists) return;
                await File(staged).copy(target.path);
                if (!await Isolate.run(
                  () => sleepWavMatchesFlac((original, target.path)),
                )) {
                  return;
                }
              }
              final now = DateTime.now().millisecondsSinceEpoch;
              final updated = math.max(
                now,
                math.max(
                      current.updatedAt,
                      currentEvent.endedAt.millisecondsSinceEpoch,
                    ) +
                    1,
              );
              currentEvent.replaceAudio(nextName, updated);
              current.updatedAt = updated;
              await scope.replaceAtomically(
                current.jsonFile,
                Uint8List.fromList(
                  utf8.encode(
                    const JsonEncoder.withIndent(
                      '  ',
                    ).convert(current.toJson()),
                  ),
                ),
              );
              committed = true;
            });
            if (committed) converted++;
          }
        } catch (e) {
          errorLog('$_logPrefix compress $original: $e');
        }
        compressionProgress.value = {
          ...compressionProgress.value,
          id: (i + 1) / events.length,
        };
      }
      if (converted > 0) notifyChanged();
      return converted;
    } finally {
      await scope.cleanTracked();
      compressionProgress.value = Map.of(compressionProgress.value)..remove(id);
    }
  }

  static Future<void> removeConfirmedOriginal(
    SleepSession session,
    SleepEvent event,
  ) async {
    var removed = false;
    await _serialized(session.path, () async {
      final current = await SleepSessionData.load(session.path);
      if (current == null || current.updatedAt != session.data.updatedAt) {
        return;
      }
      final entry = current.events
          .where((e) => e.syncFileName == event.syncFileName)
          .firstOrNull;
      if (entry == null ||
          entry.fileName != event.fileName ||
          entry.audioUpdatedAt != event.audioUpdatedAt) {
        return;
      }
      final wav = File('${session.path}/${event.syncFileName}');
      final flac = File('${session.path}/${event.fileName}');
      if (!await wav.exists() || !await flac.exists()) return;
      final beforeWav = await wav.stat();
      final beforeFlac = await flac.stat();
      if (!await Isolate.run(
        () => sleepWavMatchesFlac((wav.path, flac.path)),
      )) {
        return;
      }
      final afterWav = await wav.stat();
      final afterFlac = await flac.stat();
      if (beforeWav.size != afterWav.size ||
          beforeWav.modified != afterWav.modified ||
          beforeFlac.size != afterFlac.size ||
          beforeFlac.modified != afterFlac.modified) {
        return;
      }
      await wav.delete();
      removed = true;
    });
    if (removed) notifyChanged();
  }

  /// Removes the session and leaves tombstones so sync deletes it elsewhere.
  static Future<void> delete(SleepSession session) async {
    if (!session.synthetic) {
      await addTombstones([
        session.id,
        for (final e in session.data.events)
          chunkSyncId(session.id, e.syncFileName),
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

  static SleepSessionData _synthesize(
    String path,
    List<String> files,
    Map<String, Duration> durations,
  ) {
    const fallback = Duration(seconds: 15);
    final sessionStart =
        _parseStamp(_sessionStamp, path.split(RegExp(r'[\\/]')).last) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    // Chunk names carry the time the chunk was written, i.e. its end.
    final events = [
      for (final name in files)
        () {
          final end =
              _parseStamp(_chunkStamp, name) ?? sessionStart.add(fallback);
          final length = durations[name] ?? fallback;
          return SleepEvent(
            fileName: name,
            startedAt: end.subtract(length),
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

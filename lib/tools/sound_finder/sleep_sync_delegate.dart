import 'dart:convert';
import 'dart:io';

import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

/// Syncs finished sleep sessions: one small record per session (metadata,
/// events, analysis) and one blob record per audio chunk, so a whole night never
/// has to fit in a single request.
class SleepSyncDelegate
    with DefaultSyncDelegate
    implements SyncDelegate, VerifiedSyncDelegate {
  static final _sessionId = RegExp(r'^session-[A-Za-z0-9_-]+$');
  static final _chunkFile = RegExp(r'^[A-Za-z0-9_.-]+\.(wav|flac)$');

  @override
  String get toolId => SoundFinderTool.config.id;

  // One chunk can be up to 60 s (~5 MB WAV, ~7 MB base64), so pull one at a
  // time to stay inside a single request.
  @override
  int get syncPullBatchSize => 1;

  @override
  Duration get syncRequestTimeout => const Duration(seconds: 90);

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = <Map<String, dynamic>>[];
    final present = <String>{};
    for (final s in await SleepSessionStore.list()) {
      if (s.synthetic) continue;
      present.add(s.id);
      records.add(_meta(s.id, s.data.updatedAt));
      for (final e in s.data.events) {
        if (!s.hasFile(e)) continue;
        final id = SleepSessionStore.chunkSyncId(s.id, e.syncFileName);
        present.add(id);
        final current = s.fileSizes.containsKey(e.fileName);
        records.add(
          _meta(
            id,
            current
                ? e.audioUpdatedAt ?? e.endedAt.millisecondsSinceEpoch
                : e.endedAt.millisecondsSinceEpoch,
          ),
        );
      }
    }
    final tombstones = await SleepSessionStore.tombstones();
    for (final t in tombstones.entries) {
      if (present.contains(t.key)) continue;
      records.add({'id': t.key, 'updatedAt': t.value, 'deleted': true});
    }
    return records;
  }

  Map<String, dynamic> _meta(String id, int updatedAt) => {
    'id': id,
    'updatedAt': updatedAt,
    'deleted': false,
  };

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final (sessionId, file) = SleepSessionStore.parseSyncId(id);
    if (!_valid(sessionId, file)) return null;
    final path = await SleepSessionStore.sessionPath(sessionId);
    if (file == null) {
      final data = await SleepSessionData.load(path);
      if (data == null) return null;
      return {'shortId': id, ...data.toJson()};
    }
    final session = await SleepSessionData.load(path);
    final event = session?.events
        .where((e) => e.syncFileName == file)
        .firstOrNull;
    final audioFile = event == null
        ? File('$path/$file')
        : session!.fileFor(event);
    if (!await audioFile.exists()) return null;
    final actualName = audioFile.uri.pathSegments.last;
    return {
      'shortId': id,
      'sessionId': sessionId,
      'file': actualName,
      'audio': {
        '__type': 'blob',
        'mimeType': actualName.endsWith('.flac') ? 'audio/flac' : 'audio/wav',
        'data': base64Encode(await audioFile.readAsBytes()),
      },
    };
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    if (deleted) return;
    final (sessionId, file) = SleepSessionStore.parseSyncId(id);
    if (!_valid(sessionId, file)) return;
    final path = await SleepSessionStore.sessionPath(sessionId);
    if (file == null) {
      final session = SleepSessionData.fromJson(path, data)
        ..updatedAt = updatedAt;
      await SleepSessionStore.replace(session);
      return;
    }
    final audio = data['audio'];
    if (audio is! String) return;
    final actualName = data['file'] as String? ?? file;
    if (!_valid(sessionId, actualName) || !_sameChunk(file, actualName)) return;
    await Directory(path).create(recursive: true);
    await File('$path/$actualName').writeAsBytes(base64Decode(audio));
    await SleepSessionStore.adoptPulledChunk(
      path,
      syncFile: file,
      fileName: actualName,
      updatedAt: updatedAt,
    );
    SleepSessionStore.notifyChanged();
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (!wasDeleted) return;
    await SleepSessionStore.removeTombstone(id);
    final (sessionId, file) = SleepSessionStore.parseSyncId(id);
    if (!_valid(sessionId, file)) return;
    final path = await SleepSessionStore.sessionPath(sessionId);
    if (file == null) {
      await SleepSessionStore.deleteDir(path);
    } else {
      final session = await SleepSessionData.load(path);
      final event = session?.events
          .where((e) => e.syncFileName == file)
          .firstOrNull;
      if (event != null &&
          event.fileName != file &&
          _valid(sessionId, event.fileName) &&
          _sameChunk(file, event.fileName)) {
        await SleepSessionStore.deleteFile('$path/${event.fileName}');
      }
      await SleepSessionStore.deleteFile('$path/$file');
    }
    SleepSessionStore.notifyChanged();
  }

  @override
  Future<void> verifiedRemoteRecords(Map<String, int> records) async {
    for (final session in await SleepSessionStore.list()) {
      if (session.synthetic || records[session.id] != session.data.updatedAt) {
        continue;
      }
      for (final event in session.data.events) {
        if (event.fileName == event.syncFileName ||
            event.audioUpdatedAt == null ||
            records[SleepSessionStore.chunkSyncId(
                  session.id,
                  event.syncFileName,
                )] !=
                event.audioUpdatedAt ||
            !_valid(session.id, event.syncFileName) ||
            !_valid(session.id, event.fileName) ||
            !_sameChunk(event.syncFileName, event.fileName)) {
          continue;
        }
        await SleepSessionStore.removeConfirmedOriginal(session, event);
      }
    }
  }

  /// Ids come from the server and become paths, so nothing may escape the
  /// sessions directory.
  bool _valid(String sessionId, String? file) =>
      _sessionId.hasMatch(sessionId) &&
      (file == null || _chunkFile.hasMatch(file));

  bool _sameChunk(String a, String b) =>
      a == b ||
      (a.endsWith('.wav') && b == '${a.substring(0, a.length - 4)}.flac');
}

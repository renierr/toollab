import 'dart:convert';
import 'dart:io';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

typedef SleepChunkPull = Future<Map<String, dynamic>?> Function(String id);

/// Resolves a chunk's audio: the local file, or for an offloaded chunk a
/// temporary copy fetched from the server.
class SleepCloudAudio {
  SleepCloudAudio(this._pull);

  factory SleepCloudAudio.fromAppState(AppState app) =>
      SleepCloudAudio((id) async {
        final toolId = SoundFinderTool.config.id;
        if (!app.syncEnabled || !app.syncsTool(toolId)) return null;
        final records = await SyncService.pullRecords(
          baseUrl: app.syncServerUrl,
          userId: app.syncUserId,
          toolId: toolId,
          ids: [id],
          timeout: const Duration(seconds: 30),
        );
        return records[id];
      });

  static const _logPrefix = '[SleepCloudAudio]';
  static const _maxCached = 8;
  static final _chunkName = RegExp(r'^[A-Za-z0-9_.-]+\.(wav|flac)$');

  final SleepChunkPull _pull;
  final TempFileScope _scope = TempFileManager.createScope();
  final Map<String, String> _cached = {};
  final Map<String, Future<File?>> _pending = {};

  /// Null when the audio is neither local nor fetchable right now.
  Future<File?> fileFor(SleepSession session, SleepEvent event) async {
    final local = session.data.fileFor(event);
    if (session.hasFile(event) && await local.exists()) return local;
    if (!session.isOffloaded(event)) return null;
    final id = SleepSessionStore.chunkSyncId(session.id, event.syncFileName);
    return _pending[id] ??= _fetch(id).whenComplete(() => _pending.remove(id));
  }

  Future<File?> _fetch(String id) async {
    final cached = _cached.remove(id);
    if (cached != null) {
      final file = await _scope.resolveFile(cached);
      if (await file.exists()) {
        _cached[id] = cached;
        return file;
      }
    }
    try {
      final data = await _pull(id);
      final audio = data?['audio'];
      final file = data?['file'];
      if (audio is! String || file is! String || !_chunkName.hasMatch(file)) {
        return null;
      }
      // The extension picks the decoder, so the name ends in the chunk's own.
      final name = 'sleep-cloud-${DateTime.now().microsecondsSinceEpoch}-$file';
      await _scope.createFile(name, bytes: base64Decode(audio));
      _cached[id] = name;
      while (_cached.length > _maxCached) {
        await _scope.deleteFile(_cached.remove(_cached.keys.first)!);
      }
      return await _scope.resolveFile(name);
    } catch (e) {
      errorLog('$_logPrefix fetch $id: $e');
      return null;
    }
  }

  Future<void> dispose() => _scope.cleanTracked();
}

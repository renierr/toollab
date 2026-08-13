import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'store/health_store.dart';

/// Backend sync for the health dashboard, one record per (UTC day, writer).
///
/// The engine is row-per-record and this tool's dense tables are millions of
/// rows, so the record here is a whole day of one app's data rather than a
/// single reading. Keying on the writing app rather than on the device is what
/// makes merging correct: an app's readings for a day are the same data whoever
/// imported them, so two devices importing different writers produce different
/// chunks and both survive, while two importing the same writer produce the
/// same content and last-writer-wins is a no-op instead of a clobber.
///
/// A cursor is implemented for real here, unlike every other tool, because a
/// decade is roughly eleven thousand chunks and re-reading that metadata on
/// every run is the one cost this design cannot absorb.
class HealthSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  static const _cursorPrefix = 'sync_cursor_';

  @override
  String get toolId => HealthDashboardTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async =>
      _asRecords(await HealthStore.instance.chunkManifest());

  @override
  Future<List<Map<String, dynamic>>> getLocalPendingSyncRecords() async =>
      _asRecords(await HealthStore.instance.chunkManifest(onlyDirty: true));

  /// The mixin's version scans the whole manifest per id. A decade is around
  /// eleven thousand chunks against a page of five hundred ids, so the lookup
  /// is a set here.
  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecordsByIds(
    List<String> ids,
  ) async {
    final wanted = ids.toSet();
    final chunks = await HealthStore.instance.chunkManifest();
    return _asRecords(chunks.where((chunk) => wanted.contains(chunk.id)));
  }

  List<Map<String, dynamic>> _asRecords(Iterable<HealthChunkMeta> chunks) => [
    for (final chunk in chunks)
      {'id': chunk.id, 'updatedAt': chunk.updatedAt, 'deleted': chunk.deleted},
  ];

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final parsed = HealthChunkMeta.parseId(id);
    if (parsed == null) return null;
    return HealthStore.instance.chunkPayload(parsed.$1, parsed.$2);
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final parsed = HealthChunkMeta.parseId(id);
    if (parsed == null) return;
    if (deleted) {
      await HealthStore.instance.finalizeChunk(parsed.$1, parsed.$2, true);
      return;
    }
    await HealthStore.instance.applyChunk(
      day: parsed.$1,
      package: parsed.$2,
      data: data,
      serverUpdatedAt: updatedAt,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    final parsed = HealthChunkMeta.parseId(id);
    if (parsed == null) return;
    await HealthStore.instance.finalizeChunk(parsed.$1, parsed.$2, wasDeleted);
  }

  /// Keyed by [syncId] rather than by tool: the engine namespaces the server
  /// side per user, and a cursor from one user's namespace promises nothing
  /// about another's.
  @override
  Future<String?> getSyncCursor(String syncId) =>
      DatabaseService.instance.getSetting(toolId, '$_cursorPrefix$syncId');

  @override
  Future<void> saveSyncCursor(String syncId, String cursor) => DatabaseService
      .instance
      .setSetting(toolId, '$_cursorPrefix$syncId', cursor);
}

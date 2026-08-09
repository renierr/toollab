import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'health_database.dart';

class HealthDashboardSyncDelegate
    with DefaultSyncDelegate
    implements SyncDelegate {
  static const _cursorPrefix = HealthDatabase.syncCursorPrefix;
  @override
  String get toolId => HealthDashboardTool.config.id;

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) =>
      HealthDatabase.instance.finalizeCanonicalSync(id, wasDeleted);

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    return HealthDatabase.instance.canonicalSyncRecord(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await HealthDatabase.instance.canonicalSyncRecords();
    return records
        .map(
          (record) => {
            'id': record['id'],
            'updatedAt': record['updated_at'],
            'deleted': (record['deleted'] as int) == 1,
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecordsByIds(
    List<String> ids,
  ) async {
    final records = await HealthDatabase.instance.canonicalSyncRecordsByIds(
      ids,
    );
    return records
        .map(
          (record) => {
            'id': record['id'],
            'updatedAt': record['updated_at'],
            'deleted': (record['deleted'] as int) == 1,
          },
        )
        .toList();
  }

  @override
  Future<String?> getSyncCursor(String syncId) => DatabaseService.instance
      .getSetting(HealthDashboardTool.config.id, '$_cursorPrefix$syncId');

  @override
  Future<void> saveSyncCursor(String syncId, String cursor) =>
      DatabaseService.instance.setSetting(
        HealthDashboardTool.config.id,
        '$_cursorPrefix$syncId',
        cursor,
      );

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    await HealthDatabase.instance.savePulledCanonical(
      id: id,
      data: data,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }
}

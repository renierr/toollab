import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'health_database.dart';
import 'health_record.dart';

class HealthDashboardSyncDelegate implements SyncDelegate {
  static const _cursorPrefix = 'sync_cursor_';
  @override
  String get toolId => HealthDashboardTool.config.id;

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) =>
      HealthDatabase.instance.finalizeSync(id, wasDeleted);

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final record = await HealthDatabase.instance.record(id);
    if (record == null || record.deleted) return null;
    return {
      'id': record.id,
      'source': record.source.name,
      'sourceRecordId': record.sourceRecordId,
      'type': record.type,
      'startTime': record.startTime,
      'endTime': record.endTime,
      'value': record.value,
      'sourceName': record.sourceName,
      'duplicateOf': record.duplicateOf,
      'aggregateIncluded': record.aggregateIncluded,
      'createdAt': record.createdAt,
      'updatedAt': record.updatedAt,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await HealthDatabase.instance.syncRecords();
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
  ) async =>
      _toSyncMetadata(await HealthDatabase.instance.syncRecordsByIds(ids));

  @override
  Future<List<Map<String, dynamic>>> getLocalPendingSyncRecords() async =>
      _toSyncMetadata(await HealthDatabase.instance.pendingSyncRecords());

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

  List<Map<String, dynamic>> _toSyncMetadata(
    List<Map<String, dynamic>> records,
  ) => records
      .map(
        (record) => {
          'id': record['id'],
          'updatedAt': record['updated_at'],
          'deleted': (record['deleted'] as int) == 1,
        },
      )
      .toList();

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await HealthDatabase.instance.savePulled(
      HealthRecord(
        id: id,
        source: HealthSource.values.byName(
          data['source'] as String? ?? 'manual',
        ),
        sourceRecordId: data['sourceRecordId'] as String? ?? id,
        type: data['type'] as String? ?? 'unknown',
        startTime: data['startTime'] as int? ?? updatedAt,
        endTime: data['endTime'] as int? ?? updatedAt,
        value: Map<String, dynamic>.from(data['value'] as Map? ?? const {}),
        sourceName: data['sourceName'] as String?,
        duplicateOf: data['duplicateOf'] as String?,
        aggregateIncluded: data['aggregateIncluded'] as bool? ?? true,
        createdAt: data['createdAt'] as int? ?? now,
        updatedAt: updatedAt,
        deleted: deleted,
        synced: true,
      ),
    );
  }
}

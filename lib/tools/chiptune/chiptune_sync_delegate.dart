import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/chiptune/chiptune_archive.dart';

class ChiptuneSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  @override
  String get toolId => ChiptuneArchive.toolId;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await ChiptuneArchive.instance.getSyncRecords();
    return records
        .map(
          (r) => {
            'id': r['short_id'] as String,
            'updatedAt': r['updated_at'] as int,
            'deleted': (r['deleted'] as int) == 1,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) {
    return ChiptuneArchive.instance.getRecordData(id);
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) {
    return ChiptuneArchive.instance.savePulledRecord(
      id: id,
      data: data,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) {
    if (wasDeleted) {
      return ChiptuneArchive.instance.hardDelete(id);
    }
    return ChiptuneArchive.instance.markSynced(id);
  }
}

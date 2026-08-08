import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'sketch_board_db_helper.dart';

class SketchBoardSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  @override
  String get toolId => SketchBoardTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await SketchBoardDbHelper.instance.getSyncRecords();
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
    return SketchBoardDbHelper.instance.getRecordDataForSync(id);
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) {
    return SketchBoardDbHelper.instance.savePulledRecord(
      id: id,
      data: data,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) {
    if (wasDeleted) {
      return SketchBoardDbHelper.instance.hardDelete(id);
    }
    return SketchBoardDbHelper.instance.markSynced(id);
  }
}

import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'signatures_db_helper.dart';

class SignaturesSyncDelegate implements SyncDelegate {
  @override
  String get toolId => SignaturesTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await SignaturesDbHelper.instance.getSyncRecords();
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
    return SignaturesDbHelper.instance.getRecordDataForSync(id);
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) {
    return SignaturesDbHelper.instance.savePulledRecord(
      id: id,
      data: data,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) {
    if (wasDeleted) {
      return SignaturesDbHelper.instance.hardDelete(id);
    }
    return SignaturesDbHelper.instance.markSynced(id);
  }
}

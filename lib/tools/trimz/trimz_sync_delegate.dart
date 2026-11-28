import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'models/trimz_saved_series.dart';
import 'trimz_db_helper.dart';

/// Syncs watch progress and the personal list; one record per series.
class TrimzSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  final TrimzDbHelper _db;
  final Map<String, int> _observed = {};

  TrimzSyncDelegate({TrimzDbHelper? db}) : _db = db ?? TrimzDbHelper.instance;

  @override
  String get toolId => TrimzTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await _db.syncRecords();
    _observed.addAll({for (final r in records) r.id: r.updatedAt});
    return [
      for (final r in records)
        {'id': r.id, 'updatedAt': r.updatedAt, 'deleted': r.deleted},
    ];
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async =>
      (await _db.live(id))?.toSyncData();

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    if (deleted) return finalizeLocalSync(id, true);
    await _db.savePulled(TrimzSavedSeries.fromSyncData(id, data), updatedAt);
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    final observed = _observed[id];
    if (wasDeleted && observed != null) {
      await _db.finalizeDeletion(id, observed);
    }
  }
}

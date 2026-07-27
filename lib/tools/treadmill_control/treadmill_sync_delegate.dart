import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/treadmill_control/config.dart';
import 'package:tool_lab/tools/treadmill_control/treadmill_control_db.dart';
import 'package:tool_lab/tools/treadmill_control/treadmill_session.dart';

class TreadmillSyncDelegate implements SyncDelegate {
  @override
  String get toolId => TreadmillControlTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await TreadmillControlDb.instance.getSyncRecords();
    return records
        .map(
          (r) => {
            'id': r['uid'] as String,
            'updatedAt': r['updated_at'] as int,
            'deleted': (r['deleted'] as int) == 1,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final session = await TreadmillControlDb.instance.getSessionByUid(id);
    if (session == null || session.deleted) return null;
    return {
      'uid': session.uid,
      'startTime': session.startTime,
      'endTime': session.endTime,
      'avgSpeed': session.avgSpeed,
      'maxSpeed': session.maxSpeed,
      'distance': session.distance,
      'calories': session.calories,
      'steps': session.steps,
      'avgHeartRate': session.avgHeartRate,
      'maxHeartRate': session.maxHeartRate,
      'elapsedTime': session.elapsedTime,
      'dataPoints': session.dataPoints.map((d) => d.toMap()).toList(),
      'createdAt': session.createdAt,
      'updatedAt': session.updatedAt,
    };
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    if (deleted) {
      await TreadmillControlDb.instance.savePulledSession(
        TreadmillSession.fromWorkout(
          dataPoints: const [],
          distance: 0,
          calories: 0,
          steps: 0,
          elapsedTime: 0,
          nowMs: updatedAt,
        ).copyWith(uid: id, deleted: true, updatedAt: updatedAt),
      );
      return;
    }

    final rawPoints = (data['dataPoints'] as List<dynamic>?) ?? const [];
    final dataPoints = rawPoints
        .map((p) => WorkoutDataPoint.fromMap(p as Map<String, dynamic>))
        .toList();

    final session = TreadmillSession(
      uid: id,
      startTime: data['startTime'] as int? ?? 0,
      endTime: data['endTime'] as int?,
      avgSpeed: (data['avgSpeed'] as num? ?? 0.0).toDouble(),
      maxSpeed: (data['maxSpeed'] as num? ?? 0.0).toDouble(),
      distance: (data['distance'] as num? ?? 0.0).toDouble(),
      calories: data['calories'] as int? ?? 0,
      steps: data['steps'] as int? ?? 0,
      avgHeartRate: (data['avgHeartRate'] as num? ?? 0.0).toDouble(),
      maxHeartRate: (data['maxHeartRate'] as num? ?? 0.0).toDouble(),
      elapsedTime: data['elapsedTime'] as int? ?? 0,
      dataPoints: dataPoints,
      synced: true,
      deleted: false,
      createdAt: data['createdAt'] as int? ?? updatedAt,
      updatedAt: updatedAt,
    );
    await TreadmillControlDb.instance.savePulledSession(session);
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (wasDeleted) {
      await TreadmillControlDb.instance.hardDeleteSession(id);
    } else {
      await TreadmillControlDb.instance.markSynced(id);
    }
  }
}

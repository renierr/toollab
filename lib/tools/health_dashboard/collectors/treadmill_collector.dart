import '../health_record.dart';
import '../../treadmill_control/treadmill_control_db.dart';
import '../../treadmill_control/treadmill_session.dart';
import 'health_data_collector.dart';

class TreadmillCollector implements HealthDataCollector {
  @override
  HealthSource get source => HealthSource.treadmill;

  @override
  Future<List<HealthRecord>> collect() async {
    final sessions = await TreadmillControlDb.instance.getActiveSessions();
    return sessions.map(_recordForSession).toList();
  }

  HealthRecord _recordForSession(TreadmillSession session) => HealthRecord(
    id: 'treadmill-${session.uid}',
    source: source,
    sourceRecordId: session.uid,
    type: 'workout.treadmill',
    startTime: session.startTime,
    endTime: session.endTime ?? session.startTime + session.elapsedTime * 1000,
    value: {
      'distanceKm': session.distance,
      'calories': session.calories,
      'steps': session.steps,
      'durationSeconds': session.elapsedTime,
      'averageSpeedKmh': session.avgSpeed,
      'maxSpeedKmh': session.maxSpeed,
      'averageHeartRate': session.avgHeartRate,
      'maxHeartRate': session.maxHeartRate,
      'dataPoints': session.dataPoints.map((point) => point.toMap()).toList(),
    },
    sourceName: 'ToolLab Treadmill',
    aggregateIncluded: true,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    deleted: false,
    synced: false,
  );
}

import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';

import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'treadmill_control_db.dart';
import 'treadmill_session.dart';

final treadmillHealthConnectClientIdPrefix =
    'toollab:${TreadmillControlTool.config.id}:';

class TreadmillHealthConnectPublisher {
  TreadmillHealthConnectPublisher._();

  static final instance = TreadmillHealthConnectPublisher._();
  bool _isPublishing = false;

  Future<void> publishPendingSessions({
    bool forcePermissionRequest = false,
  }) async {
    if (!Platform.isAndroid || _isPublishing) return;
    final enabled = await DatabaseService.instance.getSetting(
      TreadmillControlTool.config.id,
      'sync_to_health_connect',
    );
    // Defaults to on: Health Connect is now the only way treadmill workouts
    // reach the health dashboard, so an unset preference must not drop them.
    if (enabled == 'false' && !forcePermissionRequest) return;

    _isPublishing = true;
    try {
      final sessions = await TreadmillControlDb.instance
          .getHealthConnectPendingSessions();
      if (sessions.isEmpty && !forcePermissionRequest) return;
      final connector = await hc.HealthConnector.create();
      await connector.requestPermissions([
        hc.HealthDataType.exerciseSession.writePermission,
        hc.HealthDataType.heartRateSeries.writePermission,
        hc.HealthDataType.speedSeries.writePermission,
        hc.HealthDataType.distance.writePermission,
        hc.HealthDataType.activeEnergyBurned.writePermission,
        hc.HealthDataType.steps.writePermission,
      ]);
      for (final session in sessions) {
        // Per session: one workout Health Connect rejects must not stop the
        // others, and it stays unpublished so a later fix still picks it up.
        try {
          await connector.writeRecords(_recordsFor(session));
          await TreadmillControlDb.instance.markHealthConnectPublished(session);
        } catch (e) {
          errorLog(
            '[TreadmillControl] Publishing session ${session.uid} failed: $e',
          );
        }
      }
    } catch (e) {
      errorLog('[TreadmillControl] Publish to Health Connect failed: $e');
    } finally {
      _isPublishing = false;
    }
  }

  List<hc.HealthRecord> _recordsFor(TreadmillSession session) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    // A sample's timestamp is seconds on the workout counter, which the
    // treadmill's own telemetry also writes and can therefore rewind, while the
    // session window is built from the counter's final value. A point stamped
    // past that value made Health Connect reject the whole batch: "Time instant
    // values must be within session interval". The window is widened to cover
    // every sample instead of dropping real measurements, and a session with no
    // duration still gets a non-empty one, which Health Connect also requires.
    final points =
        session.dataPoints.where((point) => point.timestamp >= 0).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final lastSampleSecond = points.isEmpty ? 0 : points.last.timestamp;
    final declaredEnd = DateTime.fromMillisecondsSinceEpoch(
      session.endTime ?? session.startTime + session.elapsedTime * 1000,
    );
    final sampleEnd = start.add(Duration(seconds: lastSampleSecond));
    var end = declaredEnd.isAfter(sampleEnd) ? declaredEnd : sampleEnd;
    if (!end.isAfter(start)) end = start.add(const Duration(seconds: 1));

    final records = <hc.HealthRecord>[
      hc.ExerciseSessionRecord(
        startTime: start,
        endTime: end,
        exerciseType: hc.ExerciseType.running,
        title: 'Treadmill',
        metadata: _metadata(session, 'exercise'),
      ),
    ];
    final heartRatePoints = points
        .where((point) => point.heartRate > 0)
        .toList();
    if (heartRatePoints.isNotEmpty) {
      records.add(
        hc.HeartRateSeriesRecord(
          startTime: start,
          endTime: end,
          samples: [
            for (final point in heartRatePoints)
              hc.HeartRateSample(
                time: start.add(Duration(seconds: point.timestamp)),
                rate: hc.Frequency.perMinute(point.heartRate.toDouble()),
              ),
          ],
          metadata: _metadata(session, 'heart-rate'),
        ),
      );
    }
    final speedPoints = points.where((point) => point.speed > 0).toList();
    if (speedPoints.isNotEmpty) {
      records.add(
        hc.SpeedSeriesRecord(
          startTime: start,
          endTime: end,
          samples: [
            for (final point in speedPoints)
              hc.SpeedSample(
                time: start.add(Duration(seconds: point.timestamp)),
                speed: hc.Velocity.kilometersPerHour(point.speed),
              ),
          ],
          metadata: _metadata(session, 'speed'),
        ),
      );
    }
    if (session.distance > 0) {
      records.add(
        hc.DistanceRecord(
          startTime: start,
          endTime: end,
          distance: hc.Length.kilometers(session.distance),
          metadata: _metadata(session, 'distance'),
        ),
      );
    }
    if (session.calories > 0) {
      records.add(
        hc.ActiveEnergyBurnedRecord(
          startTime: start,
          endTime: end,
          energy: hc.Energy.kilocalories(session.calories.toDouble()),
          metadata: _metadata(session, 'energy'),
        ),
      );
    }
    if (session.steps > 0) {
      records.add(
        hc.StepsRecord(
          startTime: start,
          endTime: end,
          count: hc.Number(session.steps),
          metadata: _metadata(session, 'steps'),
        ),
      );
    }
    return records;
  }

  hc.Metadata _metadata(TreadmillSession session, String type) =>
      hc.Metadata.automaticallyRecorded(
        device: const hc.Device(type: hc.DeviceType.unknown, name: 'Treadmill'),
        clientRecordId:
            '$treadmillHealthConnectClientIdPrefix${session.uid}:$type',
        clientRecordVersion: session.updatedAt,
      );
}

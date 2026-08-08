import 'dart:io';

import 'package:flutter/foundation.dart';
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
    if (enabled != 'true' && !forcePermissionRequest) return;

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
        await connector.writeRecords(_recordsFor(session));
        await TreadmillControlDb.instance.markHealthConnectPublished(session);
      }
    } catch (e) {
      debugPrint('[TreadmillControl] Publish to Health Connect failed: $e');
    } finally {
      _isPublishing = false;
    }
  }

  List<hc.HealthRecord> _recordsFor(TreadmillSession session) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(
      session.endTime ?? session.startTime + session.elapsedTime * 1000,
    );
    final records = <hc.HealthRecord>[
      hc.ExerciseSessionRecord(
        startTime: start,
        endTime: end,
        exerciseType: hc.ExerciseType.running,
        title: 'Treadmill',
        metadata: _metadata(session, 'exercise'),
      ),
    ];
    final heartRateSamples = session.dataPoints
        .where((point) => point.heartRate > 0)
        .map(
          (point) => hc.HeartRateSample(
            time: start.add(Duration(seconds: point.timestamp)),
            rate: hc.Frequency.perMinute(point.heartRate.toDouble()),
          ),
        )
        .toList();
    if (heartRateSamples.isNotEmpty) {
      records.add(
        hc.HeartRateSeriesRecord(
          startTime: start,
          endTime: end,
          samples: heartRateSamples,
          metadata: _metadata(session, 'heart-rate'),
        ),
      );
    }
    final speedSamples = session.dataPoints
        .where((point) => point.speed > 0)
        .map(
          (point) => hc.SpeedSample(
            time: start.add(Duration(seconds: point.timestamp)),
            speed: hc.Velocity.kilometersPerHour(point.speed),
          ),
        )
        .toList();
    if (speedSamples.isNotEmpty) {
      records.add(
        hc.SpeedSeriesRecord(
          startTime: start,
          endTime: end,
          samples: speedSamples,
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

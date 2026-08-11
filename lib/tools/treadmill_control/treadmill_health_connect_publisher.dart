import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/background_work_lease.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'treadmill_control_db.dart';
import 'treadmill_session.dart';

/// Every record written here carries a client record id of
/// `toollab:treadmill-control:<session uid>:<part>`.
///
/// Health Connect keys a record on (writing package, client record id), so a
/// second write of the same id replaces the first instead of adding a row. The
/// session uid travels with the backend sync and the part name is fixed, which
/// makes the id identical on every device the workout reaches - that is what
/// keeps two phones publishing one workout from producing two copies of it.
final treadmillHealthConnectClientIdPrefix =
    'toollab:${TreadmillControlTool.config.id}:';

enum TreadmillPublishOutcome {
  /// Ran; see the counts for what happened.
  ran,
  disabled,
  noPermission,
  unsupported,

  /// Skipped because the previous run was too recent.
  throttled,
}

class TreadmillPublishResult {
  final TreadmillPublishOutcome outcome;
  final int published;
  final int failed;

  const TreadmillPublishResult(
    this.outcome, {
    this.published = 0,
    this.failed = 0,
  });
}

class TreadmillHealthConnectPublisher {
  TreadmillHealthConnectPublisher._();

  static final instance = TreadmillHealthConnectPublisher._();

  /// Only the automatic triggers are throttled - opening the health dashboard
  /// would otherwise hit Health Connect again seconds after the last visit.
  /// Anything the user asked for passes `force`.
  static const _minInterval = Duration(minutes: 5);

  // The part names are part of the record identity - renaming one orphans
  // every record already written under the old name.
  static const _partExercise = 'exercise';
  static const _partHeartRate = 'heart-rate';
  static const _partSpeed = 'speed';
  static const _partDistance = 'distance';
  static const _partEnergy = 'energy';
  static const _partSteps = 'steps';

  bool _isPublishing = false;
  DateTime? _lastRun;

  List<hc.HealthDataPermission> get _writePermissions => [
    hc.HealthDataType.exerciseSession.writePermission,
    hc.HealthDataType.heartRateSeries.writePermission,
    hc.HealthDataType.speedSeries.writePermission,
    hc.HealthDataType.distance.writePermission,
    hc.HealthDataType.activeEnergyBurned.writePermission,
    hc.HealthDataType.steps.writePermission,
  ];

  /// Publishes every workout whose stored data is newer than its last publish.
  /// [force] skips the throttle and asks for permissions even when the setting
  /// is off, which is what the manual action and the settings toggle need.
  Future<TreadmillPublishResult> publishPendingSessions({
    bool force = false,
  }) async {
    if (!Platform.isAndroid) {
      return const TreadmillPublishResult(TreadmillPublishOutcome.unsupported);
    }
    if (_isPublishing) {
      return const TreadmillPublishResult(TreadmillPublishOutcome.throttled);
    }
    final enabled = await DatabaseService.instance.getSetting(
      TreadmillControlTool.config.id,
      'sync_to_health_connect',
    );
    // Defaults to on: Health Connect is now the only way treadmill workouts
    // reach the health dashboard, so an unset preference must not drop them.
    if (enabled == 'false' && !force) {
      return const TreadmillPublishResult(TreadmillPublishOutcome.disabled);
    }
    final last = _lastRun;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minInterval) {
      return const TreadmillPublishResult(TreadmillPublishOutcome.throttled);
    }

    _isPublishing = true;
    try {
      final sessions = await TreadmillControlDb.instance
          .getHealthConnectPendingSessions();
      if (sessions.isEmpty && !force) {
        _lastRun = DateTime.now();
        return const TreadmillPublishResult(TreadmillPublishOutcome.ran);
      }
      final connector = await hc.HealthConnector.create();
      if (!await _ensureWriteAccess(connector)) {
        return const TreadmillPublishResult(
          TreadmillPublishOutcome.noPermission,
        );
      }
      var published = 0;
      var failed = 0;
      // Writing a long history is minutes of platform round-trips, and the
      // screen is usually off by then - the CPU lease keeps the process from
      // being suspended mid-batch. Acquired only once there is real work, so a
      // no-op run never raises a notification.
      final work = sessions.isEmpty
          ? null
          : await BackgroundWorkLease.acquire(
              title: 'Treadmill workout sync',
              text: 'Publishing ${sessions.length} workout(s)...',
              logPrefix: 'TreadmillControl',
            );
      try {
        for (final session in sessions) {
          // Per session: one workout Health Connect rejects must not stop the
          // others, and it stays unpublished so a later fix still picks it up.
          try {
            await _publish(connector, session);
            published++;
            await work?.update('Published $published of ${sessions.length}');
          } catch (e) {
            failed++;
            errorLog(
              '[TreadmillControl] Publishing session ${session.uid} failed: $e',
            );
          }
        }
      } finally {
        await work?.release();
      }
      _lastRun = DateTime.now();
      return TreadmillPublishResult(
        TreadmillPublishOutcome.ran,
        published: published,
        failed: failed,
      );
    } catch (e) {
      errorLog('[TreadmillControl] Publish to Health Connect failed: $e');
      return const TreadmillPublishResult(
        TreadmillPublishOutcome.ran,
        failed: 1,
      );
    } finally {
      _isPublishing = false;
    }
  }

  /// Deletes every treadmill record this app wrote and clears the publish
  /// markers, so the next run recreates them. Health Connect only lets an app
  /// delete records it created, so no other writer's data can be touched.
  Future<TreadmillPublishResult> removeAllFromHealthConnect() async {
    if (!Platform.isAndroid) {
      return const TreadmillPublishResult(TreadmillPublishOutcome.unsupported);
    }
    try {
      final connector = await hc.HealthConnector.create();
      if (!await _ensureWriteAccess(connector)) {
        return const TreadmillPublishResult(
          TreadmillPublishOutcome.noPermission,
        );
      }
      final earliest = await TreadmillControlDb.instance.earliestSessionStart();
      // A workout can predate anything still stored locally, so the window
      // starts well before the oldest known session rather than at it.
      final from = DateTime.fromMillisecondsSinceEpoch(
        earliest ?? DateTime.now().millisecondsSinceEpoch,
      ).subtract(const Duration(days: 365));
      final to = DateTime.now().add(const Duration(days: 1));
      final work = await BackgroundWorkLease.acquire(
        title: 'Treadmill workout sync',
        text: 'Removing published workouts...',
        logPrefix: 'TreadmillControl',
      );
      try {
        await _deleteWindow(connector, from, to);
      } finally {
        await work.release();
      }
      final cleared = await TreadmillControlDb.instance
          .resetHealthConnectPublished();
      _lastRun = null;
      return TreadmillPublishResult(
        TreadmillPublishOutcome.ran,
        published: cleared,
      );
    } catch (e) {
      errorLog('[TreadmillControl] Removing Health Connect data failed: $e');
      return const TreadmillPublishResult(
        TreadmillPublishOutcome.ran,
        failed: 1,
      );
    }
  }

  Future<bool> _ensureWriteAccess(hc.HealthConnector connector) async {
    final needed = _writePermissions;
    final results = await connector.requestPermissions(needed);
    if (results.any((result) => result.status == hc.PermissionStatus.granted)) {
      return true;
    }
    // Already-granted permissions are not requestable, so the request comes
    // back empty-handed and the granted set has to decide.
    try {
      final granted = await connector.getGrantedPermissions();
      return needed.any(granted.contains);
    } catch (e) {
      errorLog('[TreadmillControl] Reading granted permissions failed: $e');
      return false;
    }
  }

  Future<void> _publish(
    hc.HealthConnector connector,
    TreadmillSession session,
  ) async {
    final window = _windowFor(session);
    // A republish clears the window first: a part that is no longer written -
    // a workout that lost its heart rate samples, say - keeps its own client
    // record id and would survive the rewrite untouched.
    if (session.healthConnectPublishedAt > 0) {
      await _deleteWindow(connector, window.start, window.end);
    }
    await connector.writeRecords(_recordsFor(session, window));
    await TreadmillControlDb.instance.markHealthConnectPublished(session);
  }

  Future<void> _deleteWindow(
    hc.HealthConnector connector,
    DateTime start,
    DateTime end,
  ) async {
    // The request type is not exported, and distance is missing the delete
    // capability altogether in this plugin version - its records survive a wipe
    // and are overwritten by their client record id on the next publish.
    final requests = <dynamic>[
      hc.HealthDataType.exerciseSession.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.heartRateSeries.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.speedSeries.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.activeEnergyBurned.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.steps.deleteInTimeRange(startTime: start, endTime: end),
    ];
    for (final request in requests) {
      // A type with nothing to delete, or one this Health Connect version does
      // not carry, must not abort the rest of the wipe.
      try {
        await connector.deleteRecords(request);
      } catch (e) {
        errorLog('[TreadmillControl] Delete $request failed: $e');
      }
    }
  }

  /// The interval the session and all its samples have to fit into.
  ///
  /// A sample's timestamp counts seconds on the workout counter, which the
  /// treadmill's own telemetry also writes and can therefore rewind, while the
  /// session end is derived from that counter's final value. A sample stamped
  /// past it made Health Connect reject the whole batch ("Time instant values
  /// must be within session interval"), so the window is stretched to cover
  /// every sample instead of dropping real measurements. Health Connect also
  /// rejects an empty interval, hence the one second floor.
  ({DateTime start, DateTime end}) _windowFor(TreadmillSession session) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    final declaredEnd = DateTime.fromMillisecondsSinceEpoch(
      session.endTime ?? session.startTime + session.elapsedTime * 1000,
    );
    var lastSample = 0;
    for (final point in session.dataPoints) {
      if (point.timestamp > lastSample) lastSample = point.timestamp;
    }
    final sampleEnd = start.add(Duration(seconds: lastSample));
    var end = declaredEnd.isAfter(sampleEnd) ? declaredEnd : sampleEnd;
    if (!end.isAfter(start)) end = start.add(const Duration(seconds: 1));
    return (start: start, end: end);
  }

  List<hc.HealthRecord> _recordsFor(
    TreadmillSession session,
    ({DateTime start, DateTime end}) window,
  ) {
    final records = <hc.HealthRecord>[
      hc.ExerciseSessionRecord(
        startTime: window.start,
        endTime: window.end,
        exerciseType: hc.ExerciseType.running,
        title: 'Treadmill',
        metadata: _metadata(session, _partExercise),
      ),
    ];
    final heartRate = _samples(session, window, (p) => p.heartRate > 0);
    if (heartRate.isNotEmpty) {
      records.add(
        hc.HeartRateSeriesRecord(
          startTime: window.start,
          endTime: window.end,
          samples: [
            for (final sample in heartRate)
              hc.HeartRateSample(
                time: sample.time,
                rate: hc.Frequency.perMinute(sample.point.heartRate.toDouble()),
              ),
          ],
          metadata: _metadata(session, _partHeartRate),
        ),
      );
    }
    final speed = _samples(session, window, (p) => p.speed > 0);
    if (speed.isNotEmpty) {
      records.add(
        hc.SpeedSeriesRecord(
          startTime: window.start,
          endTime: window.end,
          samples: [
            for (final sample in speed)
              hc.SpeedSample(
                time: sample.time,
                speed: hc.Velocity.kilometersPerHour(sample.point.speed),
              ),
          ],
          metadata: _metadata(session, _partSpeed),
        ),
      );
    }
    if (session.distance > 0) {
      records.add(
        hc.DistanceRecord(
          startTime: window.start,
          endTime: window.end,
          distance: hc.Length.kilometers(session.distance),
          metadata: _metadata(session, _partDistance),
        ),
      );
    }
    if (session.calories > 0) {
      records.add(
        hc.ActiveEnergyBurnedRecord(
          startTime: window.start,
          endTime: window.end,
          energy: hc.Energy.kilocalories(session.calories.toDouble()),
          metadata: _metadata(session, _partEnergy),
        ),
      );
    }
    if (session.steps > 0) {
      records.add(
        hc.StepsRecord(
          startTime: window.start,
          endTime: window.end,
          count: hc.Number(session.steps),
          metadata: _metadata(session, _partSteps),
        ),
      );
    }
    return records;
  }

  /// Samples inside [window], in order and one per instant. Clamping can push
  /// two samples onto the same boundary instant, and a series with a repeated
  /// time is rejected as well, so the later reading wins.
  List<({DateTime time, WorkoutDataPoint point})> _samples(
    TreadmillSession session,
    ({DateTime start, DateTime end}) window,
    bool Function(WorkoutDataPoint point) keep,
  ) {
    final byInstant = <int, WorkoutDataPoint>{};
    for (final point in session.dataPoints) {
      if (point.timestamp < 0 || !keep(point)) continue;
      var time = window.start.add(Duration(seconds: point.timestamp));
      if (time.isBefore(window.start)) time = window.start;
      if (time.isAfter(window.end)) time = window.end;
      byInstant[time.millisecondsSinceEpoch] = point;
    }
    final instants = byInstant.keys.toList()..sort();
    return [
      for (final instant in instants)
        (
          time: DateTime.fromMillisecondsSinceEpoch(instant),
          point: byInstant[instant]!,
        ),
    ];
  }

  hc.Metadata _metadata(TreadmillSession session, String part) =>
      hc.Metadata.automaticallyRecorded(
        device: const hc.Device(type: hc.DeviceType.unknown, name: 'Treadmill'),
        clientRecordId:
            '$treadmillHealthConnectClientIdPrefix${session.uid}:$part',
        // Bumped on every local edit and carried across devices by the backend
        // sync, so the newest version of a workout always wins the upsert.
        clientRecordVersion: session.updatedAt,
      );
}

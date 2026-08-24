import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/background_work_lease.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'renpho_body_metrics.dart';
import 'renpho_measurement.dart';
import 'renpho_measurement_db.dart';

/// Every record carries a client record id of
/// `toollab:renpho-ble-probe:<measurement uid>:<part>`.
///
/// Health Connect keys a record on (writing package, client record id), so
/// republishing replaces rather than duplicates. The uid travels with the
/// backend sync, which is what keeps two phones publishing the same scan from
/// producing two rows.
final renphoHealthConnectClientIdPrefix =
    'toollab:${RenphoBleProbeTool.config.id}:';

const renphoSyncToHealthConnectKey = 'sync_to_health_connect';

enum RenphoPublishOutcome {
  ran,
  disabled,
  noPermission,
  unsupported,
  throttled,
}

class RenphoPublishResult {
  final RenphoPublishOutcome outcome;
  final int published;
  final int failed;

  const RenphoPublishResult(
    this.outcome, {
    this.published = 0,
    this.failed = 0,
  });
}

class RenphoHealthConnectPublisher {
  RenphoHealthConnectPublisher._();
  static final instance = RenphoHealthConnectPublisher._();

  /// Only automatic triggers are throttled; anything the user asked for passes
  /// `force`.
  static const _minInterval = Duration(minutes: 5);

  // Part names are half of a record's identity — renaming one orphans every
  // record already written under the old name.
  static const _partWeight = 'weight';
  static const _partBodyFat = 'body-fat';
  static const _partLeanMass = 'lean-mass';
  static const _partBoneMass = 'bone-mass';
  static const _partBodyWater = 'body-water';
  static const _partBmr = 'bmr';

  bool _publishing = false;
  DateTime? _lastRun;

  List<hc.HealthDataPermission> get _writePermissions => [
    hc.HealthDataType.weight.writePermission,
    hc.HealthDataType.bodyFatPercentage.writePermission,
    hc.HealthDataType.leanBodyMass.writePermission,
    hc.HealthDataType.boneMass.writePermission,
    hc.HealthDataType.bodyWaterMass.writePermission,
    hc.HealthDataType.basalMetabolicRate.writePermission,
  ];

  Future<bool> isEnabled() async =>
      await DatabaseService.instance.getSetting(
        RenphoBleProbeTool.config.id,
        renphoSyncToHealthConnectKey,
      ) ==
      'true';

  Future<void> setEnabled(bool enabled) => DatabaseService.instance.setSetting(
    RenphoBleProbeTool.config.id,
    renphoSyncToHealthConnectKey,
    enabled.toString(),
  );

  /// Publishes every scan whose stored data is newer than its last publish.
  /// [force] asks for permissions even when the setting is off, which is what
  /// the manual action and the settings toggle need. [skipThrottle] is for a
  /// newly saved scan, which must not wait behind an earlier background check.
  Future<RenphoPublishResult> publishPending({
    bool force = false,
    bool skipThrottle = false,
  }) async {
    if (!Platform.isAndroid) {
      return const RenphoPublishResult(RenphoPublishOutcome.unsupported);
    }
    if (_publishing) {
      return const RenphoPublishResult(RenphoPublishOutcome.throttled);
    }
    // Body composition is personal even by health-data standards, so this one
    // stays off until it is switched on.
    if (!force && !await isEnabled()) {
      return const RenphoPublishResult(RenphoPublishOutcome.disabled);
    }
    final last = _lastRun;
    if (!force &&
        !skipThrottle &&
        last != null &&
        DateTime.now().difference(last) < _minInterval) {
      return const RenphoPublishResult(RenphoPublishOutcome.throttled);
    }

    _publishing = true;
    try {
      final pending = await RenphoMeasurementDb.instance.healthConnectPending();
      if (pending.isEmpty && !force) {
        _lastRun = DateTime.now();
        return const RenphoPublishResult(RenphoPublishOutcome.ran);
      }
      final connector = await hc.HealthConnector.create();
      final granted = await _grantedWriteTypes(connector);
      if (granted.isEmpty) {
        return const RenphoPublishResult(RenphoPublishOutcome.noPermission);
      }
      var published = 0;
      var failed = 0;
      final work = pending.isEmpty
          ? null
          : await BackgroundWorkLease.acquire(
              title: 'Renpho scale sync',
              text: 'Publishing ${pending.length} measurement(s)...',
              logPrefix: 'RenphoScale',
            );
      try {
        for (final measurement in pending) {
          // One rejected scan must not stop the others, and it stays
          // unpublished so a later fix still picks it up.
          try {
            await _publish(connector, measurement, granted);
            published++;
            await work?.update('Published $published of ${pending.length}');
          } catch (e) {
            failed++;
            errorLog('[RenphoScale] Publishing ${measurement.uid} failed: $e');
          }
        }
      } finally {
        await work?.release();
      }
      // Only a clean run arms the throttle, so a scan that failed to reach
      // Health Connect is retried on the next open instead of being held back
      // for five minutes.
      if (failed == 0) _lastRun = DateTime.now();
      return RenphoPublishResult(
        RenphoPublishOutcome.ran,
        published: published,
        failed: failed,
      );
    } catch (e) {
      errorLog('[RenphoScale] Publish to Health Connect failed: $e');
      return const RenphoPublishResult(RenphoPublishOutcome.ran, failed: 1);
    } finally {
      _publishing = false;
    }
  }

  /// Deletes every scale record this app wrote and clears the publish markers,
  /// so the next run recreates them. Health Connect only lets an app delete its
  /// own records, so no other writer's data can be touched.
  Future<RenphoPublishResult> removeAll() async {
    if (!Platform.isAndroid) {
      return const RenphoPublishResult(RenphoPublishOutcome.unsupported);
    }
    try {
      final connector = await hc.HealthConnector.create();
      if ((await _grantedWriteTypes(connector)).isEmpty) {
        return const RenphoPublishResult(RenphoPublishOutcome.noPermission);
      }
      final earliest = await RenphoMeasurementDb.instance.earliestMeasurement();
      // A scan can predate anything still stored locally, so the window opens
      // well before the oldest known measurement.
      final from = DateTime.fromMillisecondsSinceEpoch(
        earliest ?? DateTime.now().millisecondsSinceEpoch,
      ).subtract(const Duration(days: 365));
      final to = DateTime.now().add(const Duration(days: 1));
      final work = await BackgroundWorkLease.acquire(
        title: 'Renpho scale sync',
        text: 'Removing published measurements...',
        logPrefix: 'RenphoScale',
      );
      try {
        await _deleteWindow(connector, from, to);
      } finally {
        await work.release();
      }
      final cleared = await RenphoMeasurementDb.instance
          .resetHealthConnectPublished();
      _lastRun = null;
      return RenphoPublishResult(RenphoPublishOutcome.ran, published: cleared);
    } catch (e) {
      errorLog('[RenphoScale] Removing Health Connect data failed: $e');
      return const RenphoPublishResult(RenphoPublishOutcome.ran, failed: 1);
    }
  }

  /// The write types worth attempting - advisory, not a verdict. Health
  /// Connect revokes single types (the unused-app reset, a type the user
  /// unticked, a type this version does not carry), so one missing type must
  /// not keep the weight of every scan out; and when the permission state
  /// cannot be read at all, every type is attempted rather than none, because
  /// a write without permission fails only its own type.
  Future<Set<hc.HealthDataPermission>> _grantedWriteTypes(
    hc.HealthConnector connector,
  ) async {
    final needed = _writePermissions;
    var read = await _readGranted(connector);
    final granted = {...?read?.where(needed.contains)};
    final missing = needed.where((p) => !granted.contains(p)).toList();
    if (missing.isNotEmpty) {
      // A background run has no activity to show the sheet on, so this can
      // throw; whatever is already granted still gets written.
      try {
        for (final result in await connector.requestPermissions(missing)) {
          final permission = result.permission;
          if (result.status == hc.PermissionStatus.granted &&
              permission is hc.HealthDataPermission) {
            granted.add(permission);
          }
        }
        final after = await _readGranted(connector);
        if (after != null) {
          read = after;
          granted.addAll(needed.where(after.contains));
        }
      } catch (e) {
        errorLog('[RenphoScale] Requesting write permissions failed: $e');
      }
    }
    if (granted.isEmpty && read == null) return needed.toSet();
    if (granted.length != needed.length) {
      debugLog(
        '[RenphoScale] ${granted.length}/${needed.length} write permissions granted',
      );
    }
    return granted;
  }

  /// Null when the permission state could not be read, which is not the same as
  /// nothing being granted.
  Future<Set<hc.HealthDataPermission>?> _readGranted(
    hc.HealthConnector connector,
  ) async {
    try {
      return (await connector.getGrantedPermissions())
          .whereType<hc.HealthDataPermission>()
          .toSet();
    } catch (e) {
      errorLog('[RenphoScale] Reading granted permissions failed: $e');
      return null;
    }
  }

  /// Written one type at a time: a single record Health Connect rejects would
  /// otherwise take the whole scan down with it. The scan counts as published
  /// only when every writable type went through, so a transient failure is
  /// retried - the client record id makes a repeat an upsert, never a
  /// duplicate.
  Future<void> _publish(
    hc.HealthConnector connector,
    RenphoMeasurement measurement,
    Set<hc.HealthDataPermission> granted,
  ) async {
    var wrote = 0;
    final failures = <String>[];
    for (final group in _recordGroups(measurement)) {
      if (!granted.contains(group.permission)) continue;
      try {
        await connector.writeRecords(group.records);
        wrote++;
      } catch (e) {
        failures.add('${group.part}: $e');
      }
    }
    if (wrote == 0) {
      throw StateError(
        failures.isEmpty ? 'no writable record types' : failures.join('; '),
      );
    }
    if (failures.isNotEmpty) throw StateError(failures.join('; '));
    await RenphoMeasurementDb.instance.markHealthConnectPublished(measurement);
  }

  Future<void> _deleteWindow(
    hc.HealthConnector connector,
    DateTime start,
    DateTime end,
  ) async {
    final requests = [
      hc.HealthDataType.weight.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.bodyFatPercentage.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.leanBodyMass.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.boneMass.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.bodyWaterMass.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
      hc.HealthDataType.basalMetabolicRate.deleteInTimeRange(
        startTime: start,
        endTime: end,
      ),
    ];
    for (final request in requests) {
      // A type with nothing to delete, or one this Health Connect version does
      // not carry, must not abort the rest of the wipe.
      try {
        await connector.deleteRecords(request);
      } catch (e) {
        errorLog('[RenphoScale] Delete $request failed: $e');
      }
    }
  }

  /// Health Connect rejects an out-of-range value and takes the whole batch
  /// down with it, so each derived figure is clamped to the type's own limits.
  List<_RenphoRecordGroup> _recordGroups(RenphoMeasurement measurement) {
    final derived = RenphoDerived(measurement);
    final time = measurement.measuredAt;
    return [
      _RenphoRecordGroup(
        _partWeight,
        hc.HealthDataType.weight.writePermission,
        [
          hc.WeightRecord(
            time: time,
            weight: hc.Mass.kilograms(
              renphoClamp(measurement.weightKg, 1, 1000),
            ),
            metadata: _metadata(measurement, _partWeight),
          ),
        ],
      ),
      _RenphoRecordGroup(
        _partBodyFat,
        hc.HealthDataType.bodyFatPercentage.writePermission,
        [
          hc.BodyFatPercentageRecord(
            time: time,
            percentage: hc.Percentage.fromWhole(
              renphoClamp(measurement.bodyFatPercent, 0, 100),
            ),
            metadata: _metadata(measurement, _partBodyFat),
          ),
        ],
      ),
      _RenphoRecordGroup(
        _partLeanMass,
        hc.HealthDataType.leanBodyMass.writePermission,
        [
          hc.LeanBodyMassRecord(
            time: time,
            mass: hc.Mass.kilograms(
              renphoClamp(derived.fatFreeMassKg, 1, 1000),
            ),
            metadata: _metadata(measurement, _partLeanMass),
          ),
        ],
      ),
      _RenphoRecordGroup(
        _partBoneMass,
        hc.HealthDataType.boneMass.writePermission,
        [
          hc.BoneMassRecord(
            time: time,
            mass: hc.Mass.kilograms(renphoClamp(derived.boneMassKg, 0.1, 15)),
            metadata: _metadata(measurement, _partBoneMass),
          ),
        ],
      ),
      _RenphoRecordGroup(
        _partBodyWater,
        hc.HealthDataType.bodyWaterMass.writePermission,
        [
          hc.BodyWaterMassRecord(
            time: time,
            mass: hc.Mass.kilograms(
              renphoClamp(derived.bodyWaterMassKg, 0.3, 500),
            ),
            metadata: _metadata(measurement, _partBodyWater),
          ),
        ],
      ),
      _RenphoRecordGroup(
        _partBmr,
        hc.HealthDataType.basalMetabolicRate.writePermission,
        [
          hc.BasalMetabolicRateRecord(
            time: time,
            rate: hc.Power.kilocaloriesPerDay(
              renphoClamp(derived.bmrForExportKcal, 0, 10000),
            ),
            metadata: _metadata(measurement, _partBmr),
          ),
        ],
      ),
    ];
  }

  hc.Metadata _metadata(RenphoMeasurement measurement, String part) =>
      hc.Metadata.automaticallyRecorded(
        device: const hc.Device(
          type: hc.DeviceType.scale,
          name: 'Renpho MorphoScan Nova',
        ),
        clientRecordId:
            '$renphoHealthConnectClientIdPrefix${measurement.uid}:$part',
        // Bumped on every local edit and carried across devices by the backend
        // sync, so the newest version of a scan wins the upsert.
        clientRecordVersion: measurement.updatedAt,
      );
}

class _RenphoRecordGroup {
  final String part;
  final hc.HealthDataPermission permission;
  final List<hc.HealthRecord> records;

  const _RenphoRecordGroup(this.part, this.permission, this.records);
}

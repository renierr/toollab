import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;

import 'config.dart';
import 'renpho_measurement.dart';
import 'renpho_measurement_db.dart';

class RenphoHealthConnectPublisher {
  RenphoHealthConnectPublisher._();
  static final instance = RenphoHealthConnectPublisher._();

  Future<int> publishPending() async {
    if (!Platform.isAndroid)
      throw UnsupportedError('Health Connect is Android only.');
    final connector = await hc.HealthConnector.create();
    final permissions = [
      hc.HealthDataType.weight.writePermission,
      hc.HealthDataType.bodyFatPercentage.writePermission,
      hc.HealthDataType.leanBodyMass.writePermission,
    ];
    final requested = await connector.requestPermissions(permissions);
    if (requested.every(
      (result) => result.status != hc.PermissionStatus.granted,
    )) {
      final granted = await connector.getGrantedPermissions();
      if (!permissions.any(granted.contains)) {
        throw StateError('Health Connect write permission was not granted.');
      }
    }
    final pending = await RenphoMeasurementDb.instance.pendingHealthConnect();
    for (final measurement in pending) {
      await connector.writeRecords(_records(measurement));
      await RenphoMeasurementDb.instance.markPublished(measurement);
    }
    return pending.length;
  }

  List<hc.HealthRecord> _records(RenphoMeasurement measurement) {
    final metadata = hc.Metadata.automaticallyRecorded(
      device: const hc.Device(
        type: hc.DeviceType.scale,
        name: 'Renpho MorphoScan Nova',
      ),
      clientRecordId:
          'toollab:${RenphoBleProbeTool.config.id}:${measurement.uid}',
      clientRecordVersion: measurement.measuredAt.millisecondsSinceEpoch,
    );
    return [
      hc.WeightRecord(
        time: measurement.measuredAt,
        weight: hc.Mass.kilograms(measurement.weightKg),
        metadata: metadata,
      ),
      hc.BodyFatPercentageRecord(
        time: measurement.measuredAt,
        percentage: hc.Percentage.fromWhole(measurement.bodyFatPercent),
        metadata: metadata,
      ),
      hc.LeanBodyMassRecord(
        time: measurement.measuredAt,
        mass: hc.Mass.kilograms(measurement.fatFreeMassKg),
        metadata: metadata,
      ),
    ];
  }
}

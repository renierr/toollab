import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'renpho_measurement.dart';
import 'renpho_measurement_db.dart';

class RenphoSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  @override
  String get toolId => RenphoBleProbeTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final rows = await RenphoMeasurementDb.instance.syncRecords();
    return [
      for (final row in rows)
        {
          'id': row['uid'] as String,
          'updatedAt': (row['updated_at'] as num?)?.toInt() ?? 0,
          'deleted': (row['deleted'] as int? ?? 0) == 1,
        },
    ];
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final measurement = await RenphoMeasurementDb.instance.byUid(id);
    if (measurement == null || measurement.deleted) return null;
    return {
      'uid': measurement.uid,
      'measuredAt': measurement.measuredAt.millisecondsSinceEpoch,
      'weightKg': measurement.weightKg,
      'bmi': measurement.bmi,
      'bodyFatPercent': measurement.bodyFatPercent,
      'musclePercent': measurement.musclePercent,
      'visceralFat': measurement.visceralFat,
      'impedance': measurement.impedance,
      'stored': measurement.stored,
      'imported': measurement.imported,
      'packetHex': measurement.packetHex,
      'profileName': measurement.profileName,
      'profileSex': measurement.profileSex,
      'profileHeightCm': measurement.profileHeightCm,
      'profileAge': measurement.profileAge,
      'createdAt': measurement.createdAt,
      'updatedAt': measurement.updatedAt,
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
      await RenphoMeasurementDb.instance.savePulled(
        RenphoMeasurement(
          uid: id,
          measuredAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
          weightKg: 0,
          bmi: 0,
          bodyFatPercent: 0,
          musclePercent: 0,
          visceralFat: 0,
          impedance: const {},
          profileName: 'User',
          profileSex: 'male',
          profileHeightCm: 175,
          profileAge: 0,
          deleted: true,
          createdAt: updatedAt,
          updatedAt: updatedAt,
        ),
      );
      return;
    }

    final impedance = data['impedance'];
    await RenphoMeasurementDb.instance.savePulled(
      RenphoMeasurement(
        uid: id,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(
          (data['measuredAt'] as num?)?.toInt() ?? updatedAt,
        ),
        weightKg: (data['weightKg'] as num? ?? 0).toDouble(),
        bmi: (data['bmi'] as num? ?? 0).toDouble(),
        bodyFatPercent: (data['bodyFatPercent'] as num? ?? 0).toDouble(),
        musclePercent: (data['musclePercent'] as num? ?? 0).toDouble(),
        visceralFat: (data['visceralFat'] as num? ?? 0).toInt(),
        impedance: impedance is Map
            ? impedance.map(
                (key, value) =>
                    MapEntry(key as String, (value as num).toDouble()),
              )
            : const {},
        stored: data['stored'] as bool? ?? false,
        imported: data['imported'] as bool? ?? false,
        packetHex: data['packetHex'] as String? ?? '',
        profileName: data['profileName'] as String? ?? 'User',
        profileSex: data['profileSex'] as String? ?? 'male',
        profileHeightCm: (data['profileHeightCm'] as num? ?? 175).toDouble(),
        profileAge: (data['profileAge'] as num? ?? 0).toInt(),
        createdAt: (data['createdAt'] as num?)?.toInt() ?? updatedAt,
        updatedAt: updatedAt,
      ),
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (wasDeleted) {
      await RenphoMeasurementDb.instance.hardDelete(id);
    } else {
      await RenphoMeasurementDb.instance.markSynced(id);
    }
  }
}

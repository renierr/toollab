import 'dart:convert';

import 'renpho_measurement.dart';
import 'renpho_scale_protocol.dart';

/// Result of reading an import file: what was usable, and what was not.
class RenphoImportParse {
  final List<RenphoMeasurement> measurements;

  /// Entries that carried no usable timestamp or weight. Renpho exports mix
  /// body-composition rows with plain weigh-ins, so some skipping is normal.
  final int skipped;

  const RenphoImportParse({required this.measurements, required this.skipped});
}

/// Reads a Renpho export into measurements.
///
/// Deliberately lenient about shape. The same data reaches users as a raw cloud
/// response, as rows dumped out of a helper script, and as this tool's own sync
/// payload, and the field names differ in every one of them — so every field is
/// looked up under all the spellings seen in the wild rather than requiring one
/// canonical format.
RenphoImportParse parseRenphoImport(String source, RenphoProfile fallback) {
  final decoded = jsonDecode(source);
  final entries = _entries(decoded);
  final measurements = <RenphoMeasurement>[];
  var skipped = 0;

  for (final entry in entries) {
    if (entry is! Map) {
      skipped++;
      continue;
    }
    final row = entry.cast<String, Object?>();
    final measuredAt = _timestamp(row);
    final weight = _number(row, const [
      'weight',
      'weight_kg',
      'weightKg',
      'weightValue',
    ]);
    if (measuredAt == null || weight == null || weight <= 0) {
      skipped++;
      continue;
    }

    // A plain weigh-in has no body composition. It is still worth keeping — the
    // weight trend is the series people look at most.
    final bodyFat =
        _number(row, const [
          'bodyfat',
          'bodyFat',
          'body_fat_pct',
          'bodyFatPercent',
          'body_fat_percent',
        ]) ??
        0;
    final muscle =
        _number(row, const [
          'muscle',
          'skeletal_muscle_pct',
          'musclePercent',
          'muscle_percent',
        ]) ??
        0;
    final heightCm =
        _number(row, const ['height', 'height_cm', 'heightCm']) ??
        fallback.heightCm;
    final bmi =
        _number(row, const ['bmi']) ??
        (heightCm > 0 ? weight / _square(heightCm / 100) : 0);

    measurements.add(
      RenphoMeasurement(
        // Left empty on purpose: the insert assigns one, which keeps this
        // parser free of any database dependency.
        uid: '',
        measuredAt: measuredAt,
        weightKg: weight,
        bmi: bmi,
        bodyFatPercent: bodyFat,
        musclePercent: muscle,
        visceralFat:
            _number(row, const [
              'visfat',
              'visceral_fat_level',
              'visceralFat',
              'visceral_fat',
            ])?.round() ??
            0,
        impedance: _impedance(row),
        imported: true,
        profileName:
            _text(row, const ['profile_name', 'profileName']) ?? fallback.name,
        profileSex: _sex(row) ?? fallback.sex,
        profileHeightCm: heightCm,
        profileAge: _age(row, measuredAt) ?? fallback.ageAt(measuredAt),
      ),
    );
  }

  measurements.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  return RenphoImportParse(measurements: measurements, skipped: skipped);
}

/// Digs the record list out of whatever wrapper the export used.
List<Object?> _entries(Object? decoded) {
  if (decoded is List) return decoded;
  if (decoded is! Map) return const [];
  for (final key in const ['measurements', 'records', 'rows', 'items']) {
    final value = decoded[key];
    if (value is List) return value;
  }
  final data = decoded['data'];
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['lists', 'list', 'measurements', 'records']) {
      final value = data[key];
      if (value is List) return value;
    }
  }
  return const [];
}

DateTime? _timestamp(Map<String, Object?> row) {
  // The cloud's `timeStamp` is not a real unix epoch: across a whole export it
  // sits a fixed number of hours away from the `localCreatedAt` shipped in the
  // same record, so the local wall clock is the one to trust when both exist.
  final local = _text(row, const ['localCreatedAt', 'local_created_at']);
  final localParsed = local == null ? null : DateTime.tryParse(local);
  if (localParsed != null) return localParsed;

  final epoch = _number(row, const [
    'timeStamp',
    'timestamp',
    'time_stamp',
    'measured_at_ms',
  ]);
  if (epoch != null && epoch > 0) {
    // Cloud rows count seconds; this tool's own rows count milliseconds.
    final value = epoch.round();
    return DateTime.fromMillisecondsSinceEpoch(
      value < 100000000000 ? value * 1000 : value,
    );
  }
  final text = _text(row, const [
    'measured_at',
    'measuredAt',
    'created_at',
    'date',
    'time',
  ]);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return parsed.toLocal();
  final asEpoch = int.tryParse(text);
  if (asEpoch == null || asEpoch <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    asEpoch < 100000000000 ? asEpoch * 1000 : asEpoch,
  );
}

/// The ten impedances, either nested under `impedance` or flat alongside the
/// rest of the record as the cloud sends them.
Map<String, double> _impedance(Map<String, Object?> row) {
  final nested = row['impedance'] ?? row['impedance_json'];
  if (nested is Map) {
    final values = <String, double>{};
    for (final field in renphoImpedanceFields) {
      final value = _toNumber(nested[field]);
      if (value != null) values[field] = value;
    }
    if (values.isNotEmpty) return values;
  }
  if (nested is String && nested.isNotEmpty) {
    return decodeRenphoImpedance(nested);
  }
  final values = <String, double>{};
  for (final field in renphoImpedanceFields) {
    final value = _number(row, [field, _snake(field), _snakeLong(field)]);
    if (value != null) values[field] = value;
  }
  return values;
}

/// The age at the time of the scan. `bodyage` is deliberately not consulted —
/// that is the metabolic age the scale estimates, not the person's.
int? _age(Map<String, Object?> row, DateTime measuredAt) {
  final direct = _number(row, const [
    'measureAge',
    'measure_age',
    'age',
    'profile_age',
    'profileAge',
  ]);
  if (direct != null && direct > 0) return direct.round();
  final birthday = _text(row, const ['birthday', 'birth_date', 'birthDate']);
  final parsed = birthday == null ? null : DateTime.tryParse(birthday);
  if (parsed == null) return null;
  var age = measuredAt.year - parsed.year;
  if (DateTime(measuredAt.year, parsed.month, parsed.day).isAfter(measuredAt)) {
    age--;
  }
  return age;
}

String? _sex(Map<String, Object?> row) {
  final text = _text(row, const ['sex', 'gender', 'profile_sex', 'profileSex']);
  if (text != null) {
    final lower = text.toLowerCase();
    if (lower.startsWith('m')) return 'male';
    if (lower.startsWith('f') || lower.startsWith('w')) return 'female';
  }
  // The cloud encodes sex as 1 for male and 0 for female.
  final code = _number(row, const ['gender', 'sex']);
  if (code == null) return null;
  return code >= 1 ? 'male' : 'female';
}

double? _number(Map<String, Object?> row, List<String> keys) {
  for (final key in keys) {
    final value = _toNumber(row[key]);
    if (value != null) return value;
  }
  return null;
}

double? _toNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

String? _text(Map<String, Object?> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// `z20HandL` also arrives as `z20_hand_l` from anything that went through a
/// SQL schema.
String _snake(String field) => field
    .replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase();

/// A SQL schema tends to spell the side out: `z20_hand_left`, not `z20_hand_l`.
String _snakeLong(String field) => _snake(
  field,
).replaceFirst(RegExp(r'_l$'), '_left').replaceFirst(RegExp(r'_r$'), '_right');

double _square(double value) => value * value;

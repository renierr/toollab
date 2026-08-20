import 'dart:convert';

/// The person a scan is attributed to. Sex, height and birth date never reach
/// the scale; they feed the calculations the app does afterwards.
class RenphoProfile {
  final String name;
  final String sex;
  final double heightCm;
  final DateTime birthDate;

  /// False until the user has actually filled the profile in. A scan before
  /// that would attribute a body composition to invented defaults.
  final bool configured;

  const RenphoProfile({
    required this.name,
    required this.sex,
    required this.heightCm,
    required this.birthDate,
    this.configured = false,
  });

  static final empty = RenphoProfile(
    name: 'User',
    sex: 'male',
    heightCm: 175,
    birthDate: DateTime(1990, 1, 1),
  );

  int ageAt(DateTime at) {
    var age = at.year - birthDate.year;
    if (DateTime(at.year, birthDate.month, birthDate.day).isAfter(at)) age--;
    return age;
  }

  RenphoProfile copyWith({
    String? name,
    String? sex,
    double? heightCm,
    DateTime? birthDate,
    bool? configured,
  }) => RenphoProfile(
    name: name ?? this.name,
    sex: sex ?? this.sex,
    heightCm: heightCm ?? this.heightCm,
    birthDate: birthDate ?? this.birthDate,
    configured: configured ?? this.configured,
  );

  Map<String, Object> toJson() => {
    'name': name,
    'sex': sex,
    'heightCm': heightCm,
    'birthDate': birthDate.toIso8601String().substring(0, 10),
    'configured': configured,
  };

  factory RenphoProfile.fromJson(Map<String, dynamic> json) => RenphoProfile(
    name: json['name'] as String? ?? 'User',
    sex: json['sex'] as String? ?? 'male',
    heightCm: (json['heightCm'] as num? ?? 175).toDouble(),
    birthDate:
        DateTime.tryParse(json['birthDate'] as String? ?? '') ??
        DateTime(1990, 1, 1),
    // A profile written before this flag existed was entered by hand, so it
    // counts as configured.
    configured: json['configured'] as bool? ?? true,
  );
}

/// One scan, as the scale reported it, plus the profile it was taken under.
///
/// Only measured fields are stored. Everything the app calculates is derived on
/// read through `RenphoDerived`, so correcting a formula fixes the whole
/// history instead of only the scans taken afterwards.
class RenphoMeasurement {
  final int? id;
  final String uid;
  final DateTime measuredAt;

  // Reported by the scale.
  final double weightKg;
  final double bmi;
  final double bodyFatPercent;
  final double musclePercent;
  final int visceralFat;
  final Map<String, double> impedance;

  /// True when the record came out of the scale's own memory rather than off a
  /// live scan.
  final bool stored;
  final String packetHex;

  // The profile at the time of the scan, so a later height correction does not
  // silently rewrite old results.
  final String profileName;
  final String profileSex;
  final double profileHeightCm;
  final int profileAge;

  // Sync bookkeeping.
  final bool synced;
  final bool deleted;
  final int createdAt;
  final int updatedAt;
  final int healthConnectPublishedAt;

  const RenphoMeasurement({
    this.id,
    required this.uid,
    required this.measuredAt,
    required this.weightKg,
    required this.bmi,
    required this.bodyFatPercent,
    required this.musclePercent,
    required this.visceralFat,
    required this.impedance,
    required this.profileName,
    required this.profileSex,
    required this.profileHeightCm,
    required this.profileAge,
    this.stored = false,
    this.packetHex = '',
    this.synced = false,
    this.deleted = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.healthConnectPublishedAt = 0,
  });

  RenphoMeasurement copyWith({
    int? id,
    String? uid,
    bool? synced,
    bool? deleted,
    int? createdAt,
    int? updatedAt,
    int? healthConnectPublishedAt,
  }) => RenphoMeasurement(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    measuredAt: measuredAt,
    weightKg: weightKg,
    bmi: bmi,
    bodyFatPercent: bodyFatPercent,
    musclePercent: musclePercent,
    visceralFat: visceralFat,
    impedance: impedance,
    stored: stored,
    packetHex: packetHex,
    profileName: profileName,
    profileSex: profileSex,
    profileHeightCm: profileHeightCm,
    profileAge: profileAge,
    synced: synced ?? this.synced,
    deleted: deleted ?? this.deleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    healthConnectPublishedAt:
        healthConnectPublishedAt ?? this.healthConnectPublishedAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'uid': uid,
    'measured_at': measuredAt.millisecondsSinceEpoch,
    'weight_kg': weightKg,
    'bmi': bmi,
    'body_fat_percent': bodyFatPercent,
    'muscle_percent': musclePercent,
    'visceral_fat': visceralFat,
    'impedance_json': jsonEncode(impedance),
    'stored_record': stored ? 1 : 0,
    'packet_hex': packetHex,
    'profile_name': profileName,
    'profile_sex': profileSex,
    'profile_height_cm': profileHeightCm,
    'profile_age': profileAge,
    'synced': synced ? 1 : 0,
    'deleted': deleted ? 1 : 0,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'health_connect_published_at': healthConnectPublishedAt,
  };

  factory RenphoMeasurement.fromMap(Map<String, dynamic> row) =>
      RenphoMeasurement(
        id: row['id'] as int?,
        uid: row['uid'] as String,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(
          row['measured_at'] as int,
        ),
        weightKg: (row['weight_kg'] as num).toDouble(),
        bmi: (row['bmi'] as num).toDouble(),
        bodyFatPercent: (row['body_fat_percent'] as num).toDouble(),
        musclePercent: (row['muscle_percent'] as num).toDouble(),
        visceralFat: (row['visceral_fat'] as num).toInt(),
        impedance: decodeRenphoImpedance(row['impedance_json'] as String?),
        stored: (row['stored_record'] as int? ?? 0) == 1,
        packetHex: row['packet_hex'] as String? ?? '',
        profileName: row['profile_name'] as String? ?? 'User',
        profileSex: row['profile_sex'] as String? ?? 'male',
        profileHeightCm: (row['profile_height_cm'] as num? ?? 175).toDouble(),
        profileAge: (row['profile_age'] as num? ?? 0).toInt(),
        synced: (row['synced'] as int? ?? 0) == 1,
        deleted: (row['deleted'] as int? ?? 0) == 1,
        createdAt: (row['created_at'] as num? ?? 0).toInt(),
        updatedAt: (row['updated_at'] as num? ?? 0).toInt(),
        healthConnectPublishedAt:
            (row['health_connect_published_at'] as num? ?? 0).toInt(),
      );
}

Map<String, double> decodeRenphoImpedance(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return const {};
  return decoded.map(
    (key, value) => MapEntry(key as String, (value as num).toDouble()),
  );
}

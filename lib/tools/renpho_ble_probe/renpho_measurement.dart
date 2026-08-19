import 'dart:convert';

class RenphoProfile {
  final String name;
  final String sex;
  final double heightCm;
  final DateTime birthDate;

  const RenphoProfile({
    required this.name,
    required this.sex,
    required this.heightCm,
    required this.birthDate,
  });

  int ageAt(DateTime at) {
    var age = at.year - birthDate.year;
    if (DateTime(at.year, birthDate.month, birthDate.day).isAfter(at)) age--;
    return age;
  }

  Map<String, Object> toJson() => {
    'name': name,
    'sex': sex,
    'heightCm': heightCm,
    'birthDate': birthDate.toIso8601String().substring(0, 10),
  };

  factory RenphoProfile.fromJson(Map<String, dynamic> json) => RenphoProfile(
    name: json['name'] as String? ?? 'User',
    sex: json['sex'] as String? ?? 'male',
    heightCm: (json['heightCm'] as num? ?? 173).toDouble(),
    birthDate:
        DateTime.tryParse(json['birthDate'] as String? ?? '') ??
        DateTime(1976, 1, 1),
  );
}

class RenphoMeasurement {
  final int? id;
  final String uid;
  final DateTime measuredAt;
  final double weightKg;
  final double bmi;
  final double bodyFatPercent;
  final double musclePercent;
  final int visceralFat;
  final Map<String, double> impedance;
  final String packetHex;
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
    required this.packetHex,
    this.healthConnectPublishedAt = 0,
  });

  double get fatMassKg => weightKg * bodyFatPercent / 100;
  double get fatFreeMassKg => weightKg - fatMassKg;

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
    'packet_hex': packetHex,
    'health_connect_published_at': healthConnectPublishedAt,
  };

  factory RenphoMeasurement.fromMap(
    Map<String, dynamic> row,
  ) => RenphoMeasurement(
    id: row['id'] as int?,
    uid: row['uid'] as String,
    measuredAt: DateTime.fromMillisecondsSinceEpoch(row['measured_at'] as int),
    weightKg: (row['weight_kg'] as num).toDouble(),
    bmi: (row['bmi'] as num).toDouble(),
    bodyFatPercent: (row['body_fat_percent'] as num).toDouble(),
    musclePercent: (row['muscle_percent'] as num).toDouble(),
    visceralFat: row['visceral_fat'] as int,
    impedance:
        (jsonDecode(row['impedance_json'] as String) as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
    packetHex: row['packet_hex'] as String,
    healthConnectPublishedAt: row['health_connect_published_at'] as int? ?? 0,
  );
}

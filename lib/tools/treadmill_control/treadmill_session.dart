import 'dart:convert';

class WorkoutDataPoint {
  final int timestamp; // seconds since workout start
  final double speed;
  final double incline;
  final int heartRate;
  final double distance;
  final int calories;
  final int steps;

  WorkoutDataPoint({
    required this.timestamp,
    required this.speed,
    required this.incline,
    required this.heartRate,
    required this.distance,
    required this.calories,
    required this.steps,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp,
    'speed': speed,
    'incline': incline,
    'heart_rate': heartRate,
    'distance': distance,
    'calories': calories,
    'steps': steps,
  };

  factory WorkoutDataPoint.fromMap(Map<String, dynamic> map) =>
      WorkoutDataPoint(
        timestamp: map['timestamp'] as int? ?? 0,
        speed: (map['speed'] as num? ?? 0.0).toDouble(),
        incline: (map['incline'] as num? ?? 0.0).toDouble(),
        heartRate: map['heart_rate'] as int? ?? 0,
        distance: (map['distance'] as num? ?? 0.0).toDouble(),
        calories: map['calories'] as int? ?? 0,
        steps: map['steps'] as int? ?? 0,
      );
}

class TreadmillSession {
  final int? id;
  final String uid;
  final int startTime;
  final int? endTime;
  final double avgSpeed;
  final double maxSpeed;
  final double distance;
  final int calories;
  final int steps;
  final double avgHeartRate;
  final double maxHeartRate;
  final int elapsedTime;
  final List<WorkoutDataPoint> dataPoints;
  final bool synced;
  final bool deleted;
  final int updatedAt;
  final int createdAt;

  TreadmillSession({
    this.id,
    required this.uid,
    required this.startTime,
    this.endTime,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.distance,
    required this.calories,
    required this.steps,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.elapsedTime,
    required this.dataPoints,
    required this.synced,
    required this.deleted,
    required this.updatedAt,
    required this.createdAt,
  });

  TreadmillSession copyWith({
    int? id,
    String? uid,
    int? startTime,
    int? endTime,
    double? avgSpeed,
    double? maxSpeed,
    double? distance,
    int? calories,
    int? steps,
    double? avgHeartRate,
    double? maxHeartRate,
    int? elapsedTime,
    List<WorkoutDataPoint>? dataPoints,
    bool? synced,
    bool? deleted,
    int? updatedAt,
    int? createdAt,
  }) => TreadmillSession(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    avgSpeed: avgSpeed ?? this.avgSpeed,
    maxSpeed: maxSpeed ?? this.maxSpeed,
    distance: distance ?? this.distance,
    calories: calories ?? this.calories,
    steps: steps ?? this.steps,
    avgHeartRate: avgHeartRate ?? this.avgHeartRate,
    maxHeartRate: maxHeartRate ?? this.maxHeartRate,
    elapsedTime: elapsedTime ?? this.elapsedTime,
    dataPoints: dataPoints ?? this.dataPoints,
    synced: synced ?? this.synced,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'uid': uid,
    'start_time': startTime,
    'end_time': endTime,
    'avg_speed': avgSpeed,
    'max_speed': maxSpeed,
    'distance': distance,
    'calories': calories,
    'steps': steps,
    'avg_heart_rate': avgHeartRate,
    'max_heart_rate': maxHeartRate,
    'elapsed_time': elapsedTime,
    'data_points': jsonEncode(dataPoints.map((d) => d.toMap()).toList()),
    'synced': synced ? 1 : 0,
    'deleted': deleted ? 1 : 0,
    'updated_at': updatedAt,
    'created_at': createdAt,
  };

  factory TreadmillSession.fromMap(Map<String, dynamic> map) {
    List<WorkoutDataPoint> dps = [];
    final rawPoints = map['data_points'];
    if (rawPoints is String && rawPoints.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawPoints);
        dps = decoded
            .map((x) => WorkoutDataPoint.fromMap(x as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return TreadmillSession(
      id: map['id'] as int?,
      uid: map['uid'] as String? ?? '',
      startTime: map['start_time'] as int? ?? 0,
      endTime: map['end_time'] as int?,
      avgSpeed: (map['avg_speed'] as num? ?? 0.0).toDouble(),
      maxSpeed: (map['max_speed'] as num? ?? 0.0).toDouble(),
      distance: (map['distance'] as num? ?? 0.0).toDouble(),
      calories: map['calories'] as int? ?? 0,
      steps: map['steps'] as int? ?? 0,
      avgHeartRate: (map['avg_heart_rate'] as num? ?? 0.0).toDouble(),
      maxHeartRate: (map['max_heart_rate'] as num? ?? 0.0).toDouble(),
      elapsedTime: map['elapsed_time'] as int? ?? 0,
      dataPoints: dps,
      synced: (map['synced'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      updatedAt: map['updated_at'] as int? ?? 0,
      createdAt: map['created_at'] as int? ?? 0,
    );
  }
}

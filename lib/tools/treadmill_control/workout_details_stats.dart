import 'dart:math';

import 'treadmill_session.dart';

class WorkoutSplit {
  final double endDistance;
  final double distance;
  final int seconds;
  final int avgHeartRate;
  final bool isPartial;

  const WorkoutSplit({
    required this.endDistance,
    required this.distance,
    required this.seconds,
    required this.avgHeartRate,
    required this.isPartial,
  });

  double get paceSecondsPerKm => distance <= 0 ? 0 : seconds / distance;
}

class HeartRateZone {
  final int index;
  final int lowerBpm;
  final int upperBpm;
  final int seconds;

  const HeartRateZone({
    required this.index,
    required this.lowerBpm,
    required this.upperBpm,
    required this.seconds,
  });
}

/// Values derived from a session's sampled data points (splits, zones,
/// incline) that are not stored on the session row itself.
class WorkoutDetailsStats {
  final double avgIncline;
  final double maxIncline;
  final double minHeartRate;
  final int referenceMaxHeartRate;
  final List<WorkoutSplit> splits;
  final List<HeartRateZone> zones;

  const WorkoutDetailsStats({
    required this.avgIncline,
    required this.maxIncline,
    required this.minHeartRate,
    required this.referenceMaxHeartRate,
    required this.splits,
    required this.zones,
  });

  bool get hasIncline => maxIncline > 0;
  bool get hasZones => zones.any((zone) => zone.seconds > 0);
  int get zoneSeconds => zones.fold(0, (sum, zone) => sum + zone.seconds);

  factory WorkoutDetailsStats.from(TreadmillSession session) {
    final points = session.dataPoints;
    if (points.isEmpty) {
      return const WorkoutDetailsStats(
        avgIncline: 0,
        maxIncline: 0,
        minHeartRate: 0,
        referenceMaxHeartRate: 0,
        splits: [],
        zones: [],
      );
    }

    double inclineSum = 0;
    double maxIncline = 0;
    double minHr = double.infinity;
    double observedMaxHr = 0;
    for (final point in points) {
      inclineSum += point.incline;
      maxIncline = max(maxIncline, point.incline);
      if (point.heartRate > 0) {
        minHr = min(minHr, point.heartRate.toDouble());
        observedMaxHr = max(observedMaxHr, point.heartRate.toDouble());
      }
    }

    final reference = max(session.maxHeartRate, observedMaxHr).round();

    return WorkoutDetailsStats(
      avgIncline: inclineSum / points.length,
      maxIncline: maxIncline,
      minHeartRate: minHr.isFinite ? minHr : 0,
      referenceMaxHeartRate: reference,
      splits: _splits(points),
      zones: _zones(points, reference),
    );
  }

  static List<WorkoutSplit> _splits(List<WorkoutDataPoint> points) {
    final splits = <WorkoutSplit>[];
    int nextKm = 1;
    double prevDistance = points.first.distance;
    double prevTime = points.first.timestamp.toDouble();
    double segmentStartDistance = prevDistance;
    double segmentStartTime = prevTime;
    var heartRates = <int>[];

    for (int i = 1; i < points.length; i++) {
      final point = points[i];
      final distance = max(point.distance, prevDistance);
      if (point.heartRate > 0) heartRates.add(point.heartRate);

      while (distance >= nextKm && distance > prevDistance) {
        final crossTime =
            prevTime +
            ((nextKm - prevDistance) / (distance - prevDistance)) *
                (point.timestamp - prevTime);
        splits.add(
          WorkoutSplit(
            endDistance: nextKm.toDouble(),
            distance: nextKm - segmentStartDistance,
            seconds: (crossTime - segmentStartTime).round(),
            avgHeartRate: _average(heartRates),
            isPartial: false,
          ),
        );
        segmentStartDistance = nextKm.toDouble();
        segmentStartTime = crossTime;
        heartRates = <int>[];
        nextKm++;
      }

      prevDistance = distance;
      prevTime = point.timestamp.toDouble();
    }

    final remaining = prevDistance - segmentStartDistance;
    if (splits.isNotEmpty && remaining >= 0.05) {
      splits.add(
        WorkoutSplit(
          endDistance: prevDistance,
          distance: remaining,
          seconds: (prevTime - segmentStartTime).round(),
          avgHeartRate: _average(heartRates),
          isPartial: true,
        ),
      );
    }
    return splits;
  }

  static List<HeartRateZone> _zones(
    List<WorkoutDataPoint> points,
    int referenceMaxHeartRate,
  ) {
    if (referenceMaxHeartRate <= 0) return const [];
    const bounds = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
    final seconds = List<int>.filled(5, 0);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.heartRate <= 0) continue;
      final delta = i == 0
          ? (points.length > 1 ? points[1].timestamp - point.timestamp : 1)
          : point.timestamp - points[i - 1].timestamp;
      final step = delta.clamp(1, 60);
      final ratio = point.heartRate / referenceMaxHeartRate;
      int zone = 0;
      for (int z = 4; z >= 0; z--) {
        if (ratio >= bounds[z]) {
          zone = z;
          break;
        }
      }
      seconds[zone] += step;
    }

    return [
      for (int z = 0; z < 5; z++)
        HeartRateZone(
          index: z + 1,
          lowerBpm: (referenceMaxHeartRate * bounds[z]).round(),
          upperBpm: (referenceMaxHeartRate * bounds[z + 1]).round(),
          seconds: seconds[z],
        ),
    ];
  }

  static int _average(List<int> values) => values.isEmpty
      ? 0
      : (values.reduce((a, b) => a + b) / values.length).round();
}

String formatWorkoutDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${minutes}m ${secs.toString().padLeft(2, '0')}s';
}

String formatWorkoutClock(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

String formatPace(double secondsPerKm) {
  if (secondsPerKm <= 0 || !secondsPerKm.isFinite) return '--:--';
  final total = secondsPerKm.round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

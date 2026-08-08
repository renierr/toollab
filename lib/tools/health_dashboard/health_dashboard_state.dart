import 'package:flutter/foundation.dart';

import 'collectors/health_data_collector.dart';
import 'collectors/health_connect_collector.dart';
import 'collectors/treadmill_collector.dart';
import 'health_database.dart';
import 'health_record.dart';

class HealthDashboardState extends ChangeNotifier {
  final List<HealthDataCollector> _collectors = [
    TreadmillCollector(),
    HealthConnectCollector(),
  ];
  List<HealthRecord> records = [];
  bool isLoading = true;
  bool isCollecting = false;
  String? error;

  HealthDashboardState() {
    load();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      records = await HealthDatabase.instance.activeRecords();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Load failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> collect() async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    notifyListeners();
    try {
      for (final collector in _collectors) {
        for (final record in await collector.collect()) {
          await HealthDatabase.instance.upsertCollected(record);
        }
      }
      records = await HealthDatabase.instance.activeRecords();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Collection failed: $e');
    } finally {
      isCollecting = false;
      notifyListeners();
    }
  }

  Future<void> connectHealthConnect() async {
    try {
      await HealthConnectCollector().requestAccess();
      await collect();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Health Connect access failed: $e');
      notifyListeners();
    }
  }

  List<HealthRecord> get treadmillWorkouts =>
      records.where((record) => record.type == 'workout.treadmill').toList();

  double get totalDistanceKm => treadmillWorkouts.fold(
    0,
    (sum, record) => sum + ((record.value['distanceKm'] as num?) ?? 0),
  );

  int get totalCalories => treadmillWorkouts.fold(
    0,
    (sum, record) => sum + ((record.value['calories'] as num?) ?? 0).round(),
  );

  int get totalDurationSeconds => treadmillWorkouts.fold(
    0,
    (sum, record) =>
        sum + ((record.value['durationSeconds'] as num?) ?? 0).round(),
  );
}

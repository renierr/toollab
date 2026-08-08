import 'package:flutter/foundation.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';

import 'collectors/health_connect_collector.dart';
import 'collectors/treadmill_collector.dart';
import 'config.dart';
import 'health_database.dart';
import 'health_record.dart';
import 'health_sync_delegate.dart';

class HealthDashboardState extends ChangeNotifier {
  static const _showTreadmillWorkoutsKey = 'show_treadmill_workouts';
  static const _autoHealthConnectSyncKey = 'auto_health_connect_sync';

  final _treadmillCollector = TreadmillCollector();
  final _healthConnectCollector = HealthConnectCollector();
  List<HealthRecord> records = [];
  bool isLoading = true;
  bool isCollecting = false;
  bool showTreadmillWorkouts = true;
  bool autoHealthConnectSync = false;
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
      showTreadmillWorkouts =
          await DatabaseService.instance.getSetting(
            HealthDashboardTool.config.id,
            _showTreadmillWorkoutsKey,
          ) !=
          'false';
      autoHealthConnectSync =
          await DatabaseService.instance.getSetting(
            HealthDashboardTool.config.id,
            _autoHealthConnectSyncKey,
          ) ==
          'true';
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
      for (final record in await _treadmillCollector.collect()) {
        await HealthDatabase.instance.upsertCollected(record);
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
      await _healthConnectCollector.requestAccess();
      await syncHealthConnect();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Health Connect access failed: $e');
      notifyListeners();
    }
  }

  Future<void> syncHealthConnect() async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    notifyListeners();
    try {
      for (final record in await _healthConnectCollector.collect()) {
        await HealthDatabase.instance.upsertCollected(record);
      }
      records = await HealthDatabase.instance.activeRecords();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Health Connect sync failed: $e');
    } finally {
      isCollecting = false;
      notifyListeners();
    }
  }

  Future<void> refreshOnOpen(AppState appState) async {
    await collect();
    if (autoHealthConnectSync) {
      await syncHealthConnect();
    }
    if (!appState.syncEnabled || appState.isSyncing) return;
    try {
      await appState.syncWithBackend([HealthDashboardSyncDelegate()]);
      await load();
    } catch (e) {
      debugPrint('[HealthDashboard] Open sync failed: $e');
    }
  }

  Future<void> setAutoHealthConnectSync(bool value) async {
    if (autoHealthConnectSync == value) return;
    autoHealthConnectSync = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      HealthDashboardTool.config.id,
      _autoHealthConnectSyncKey,
      value.toString(),
    );
  }

  Future<void> setShowTreadmillWorkouts(bool value) async {
    if (showTreadmillWorkouts == value) return;
    showTreadmillWorkouts = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      HealthDashboardTool.config.id,
      _showTreadmillWorkoutsKey,
      value.toString(),
    );
  }

  List<HealthRecord> get treadmillWorkouts => showTreadmillWorkouts
      ? records.where((record) => record.type == 'workout.treadmill').toList()
      : const [];

  int get todaySteps {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return records
        .where(
          (record) =>
              record.type == 'activity.steps' && record.startTime >= today,
        )
        .fold(
          0,
          (sum, record) => sum + ((record.value['count'] as num?) ?? 0).round(),
        );
  }

  double? get latestWeightKg => _latestNumeric('body.weight', 'kilograms');

  double? get latestRestingHeartRate => _latestNumeric('heart.resting', 'bpm');

  int? get latestSleepMinutes {
    for (final record in records) {
      if (record.type == 'sleep.session') {
        return Duration(
          milliseconds: record.endTime - record.startTime,
        ).inMinutes;
      }
    }
    return null;
  }

  double? _latestNumeric(String type, String key) {
    for (final record in records) {
      if (record.type == type && record.value[key] is num) {
        return (record.value[key] as num).toDouble();
      }
    }
    return null;
  }

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

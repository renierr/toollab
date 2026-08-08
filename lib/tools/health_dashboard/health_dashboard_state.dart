import 'dart:math';

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
  static const _sourcePreferencePrefix = 'source_preference_';

  final _treadmillCollector = TreadmillCollector();
  final _healthConnectCollector = HealthConnectCollector();
  List<HealthRecord> records = [];
  bool isLoading = true;
  bool isCollecting = false;
  bool showTreadmillWorkouts = true;
  bool autoHealthConnectSync = false;
  int trendDayOffset = 0;
  final Map<String, String?> sourcePreferences = {};
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
      for (final type in _sourcePreferenceTypes) {
        sourcePreferences[type] = await DatabaseService.instance.getSetting(
          HealthDashboardTool.config.id,
          '$_sourcePreferencePrefix$type',
        );
      }
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

  static const _sourcePreferenceTypes = [
    'activity.steps',
    'body.weight',
    'heart.resting',
    'heart.rate',
    'sleep.session',
  ];

  String? preferredSource(String type) => sourcePreferences[type];

  List<String> availableSources(String type) =>
      recordsOfType(type)
          .map((record) => record.sourceName)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();

  Future<void> setPreferredSource(String type, String? source) async {
    sourcePreferences[type] = source;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      HealthDashboardTool.config.id,
      '$_sourcePreferencePrefix$type',
      source ?? '',
    );
  }

  Future<String> exportBackup() => HealthDatabase.instance.exportBackup();

  Future<int> importBackup(String path) async {
    final imported = await HealthDatabase.instance.importBackup(path);
    await load();
    return imported;
  }

  List<HealthRecord> get treadmillWorkouts => showTreadmillWorkouts
      ? records.where((record) => record.type == 'workout.treadmill').toList()
      : const [];

  List<HealthRecord> get healthConnectWorkouts => records
      .where((record) => record.type == 'workout.healthConnect')
      .toList();

  List<HealthRecord> get workouts =>
      [...treadmillWorkouts, ...healthConnectWorkouts]
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  List<HealthRecord> recordsOfType(String type, {bool preferredOnly = false}) {
    final typed = records.where((record) => record.type == type).toList();
    final source = preferredSource(type);
    if (!preferredOnly || source == null || source.isEmpty) return typed;
    final preferred = typed
        .where((record) => record.sourceName == source)
        .toList();
    return preferred.isEmpty ? typed : preferred;
  }

  DateTime get selectedDay => _dayAt(6);

  DateTime trendDayAt(int index) => _dayAt(index);

  List<HealthRecord> recordsOnDay(String type, DateTime day) {
    final typed = recordsOfType(type).where((record) => _isOnDay(record, day));
    final source = preferredSource(type);
    if (source == null || source.isEmpty) return typed.toList();
    final preferred = typed
        .where((record) => record.sourceName == source)
        .toList();
    return preferred.isEmpty ? typed.toList() : preferred;
  }

  void selectDay(DateTime day) {
    final today = DateTime.now();
    trendDayOffset = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    notifyListeners();
  }

  void previousTrendDay() {
    trendDayOffset--;
    notifyListeners();
  }

  void nextTrendDay() {
    if (trendDayOffset == 0) return;
    trendDayOffset++;
    notifyListeners();
  }

  void resetTrendDate() {
    if (trendDayOffset == 0) return;
    trendDayOffset = 0;
    notifyListeners();
  }

  DateTime get trendWeekEnd => _dayAt(6);

  List<double?> weeklyMetricValues(
    String type,
    String key, {
    bool sum = false,
  }) => List<double?>.generate(7, (index) {
    final values = recordsOnDay(type, _dayAt(index))
        .where((record) => type != 'sleep.session' || !isNap(record))
        .map((record) => _metricValue(record, key))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    if (type == 'sleep.session') return values.reduce(max);
    if (sum) return values.reduce((a, b) => a + b);
    return values.reduce((a, b) => a + b) / values.length;
  });

  double? _metricValue(HealthRecord record, String key) {
    if (record.type == 'sleep.session' && key == 'durationMinutes') {
      return Duration(
        milliseconds: record.endTime - record.startTime,
      ).inMinutes.toDouble();
    }
    if (record.type == 'workout.treadmill' && key == 'durationMinutes') {
      return ((record.value['durationSeconds'] as num?)?.toDouble() ?? 0) / 60;
    }
    return (record.value[key] as num?)?.toDouble();
  }

  bool isNap(HealthRecord record) {
    final title = (record.value['title'] as String?)?.toLowerCase() ?? '';
    return title.contains('nickerchen') || title.contains('nap');
  }

  int get todaySteps {
    return recordsOnDay('activity.steps', DateTime.now()).fold(
      0,
      (sum, record) => sum + ((record.value['count'] as num?) ?? 0).round(),
    );
  }

  double? get latestWeightKg => _latestNumeric('body.weight', 'kilograms');

  double? get latestRestingHeartRate => _latestNumeric('heart.resting', 'bpm');

  int? get latestSleepMinutes {
    for (final record in recordsOfType('sleep.session', preferredOnly: true)) {
      if (isNap(record)) continue;
      return Duration(
        milliseconds: record.endTime - record.startTime,
      ).inMinutes;
    }
    return null;
  }

  double? _latestNumeric(String type, String key) {
    for (final record in recordsOfType(type, preferredOnly: true)) {
      if (record.type == type && record.value[key] is num) {
        return (record.value[key] as num).toDouble();
      }
    }
    return null;
  }

  List<double> get weeklyDistanceKm => List<double>.generate(7, (index) {
    final day = _dayAt(index);
    return treadmillWorkouts
        .where((workout) => _isOnDay(workout, day))
        .fold(
          0,
          (sum, workout) =>
              sum + ((workout.value['distanceKm'] as num?)?.toDouble() ?? 0),
        );
  });

  List<double?> get weeklyHeartRate => List<double?>.generate(7, (index) {
    final day = _dayAt(index);
    final values = <double>[
      for (final workout in treadmillWorkouts)
        if (_isOnDay(workout, day) &&
            ((workout.value['averageHeartRate'] as num?) ?? 0) > 0)
          (workout.value['averageHeartRate'] as num).toDouble(),
      for (final record in recordsOnDay('heart.rate', day))
        if (record.type == 'heart.rate' &&
            _isOnDay(record, day) &&
            ((record.value['averageBpm'] as num?) ?? 0) > 0)
          (record.value['averageBpm'] as num).toDouble(),
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  });

  List<Map<String, dynamic>> heartRateSamplesDuring(HealthRecord session) {
    final overlapping = recordsOfType('heart.rate').where(
      (record) =>
          record.startTime < session.endTime &&
          record.endTime > session.startTime,
    );
    final source = preferredSource('heart.rate');
    final preferred = source == null || source.isEmpty
        ? const <HealthRecord>[]
        : overlapping.where((record) => record.sourceName == source).toList();
    return (preferred.isEmpty ? overlapping : preferred)
        .expand(
          (record) => (record.value['samples'] as List? ?? const []).map(
            (sample) => Map<String, dynamic>.from(sample as Map),
          ),
        )
        .where(
          (sample) =>
              ((sample['time'] as num?)?.toInt() ?? 0) >= session.startTime &&
              ((sample['time'] as num?)?.toInt() ?? 0) <= session.endTime,
        )
        .toList();
  }

  DateTime _dayAt(int index) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: trendDayOffset - 6 + index));
  }

  bool _isOnDay(HealthRecord record, DateTime day) {
    final timestamp = record.type == 'sleep.session'
        ? record.endTime
        : record.startTime;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
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

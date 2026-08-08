import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';

import 'collectors/health_connect_collector.dart';
import 'collectors/treadmill_collector.dart';
import '../treadmill_control/treadmill_health_connect_publisher.dart';
import 'config.dart';
import 'health_database.dart';
import 'health_record.dart';
import 'health_sync_delegate.dart';

class HealthDashboardState extends ChangeNotifier {
  static const _showTreadmillWorkoutsKey = 'show_treadmill_workouts';
  static const _autoHealthConnectSyncKey = 'auto_health_connect_sync';
  static const _healthConnectLastSyncKey = 'health_connect_last_sync';
  static const _sourcePreferencePrefix = 'source_preference_';
  static const _dashboardWindow = Duration(days: 120);

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
  double allTimeDistanceKm = 0;
  int allTimeCalories = 0;
  int allTimeDurationSeconds = 0;
  int allTimeSteps = 0;
  int allTimeWorkouts = 0;

  String? collectionStatus;
  int collectedRecordCount = 0;

  void _onCollectionProgress(String status, int count) {
    collectionStatus = status;
    collectedRecordCount = count;
    notifyListeners();
  }

  HealthDashboardState() {
    load();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading && records.isEmpty) {
      isLoading = true;
      notifyListeners();
    }
    error = null;
    try {
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Load failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadRecords() async {
    records = await HealthDatabase.instance.activeRecordsSince(
      DateTime.now().subtract(_dashboardWindow),
    );
    final summary = await HealthDatabase.instance.allTimeWorkoutSummary();
    allTimeDistanceKm = summary['distance']!.toDouble();
    allTimeCalories = summary['calories']!.round();
    allTimeDurationSeconds = summary['duration']!.round();
    allTimeWorkouts = summary['workouts']!.toInt();
    allTimeSteps = await HealthDatabase.instance.allTimeSteps();
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
      await _reloadRecords();
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
      await syncHealthConnect(forceFullHistory: true);
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Health Connect access failed: $e');
      notifyListeners();
    }
  }

  Future<void> syncHealthConnect({bool forceFullHistory = false}) async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    collectionStatus = 'Starting sync...';
    collectedRecordCount = 0;
    notifyListeners();
    WakeLockLease? lease;
    try {
      lease = await PowerWakeLockService.acquireFull();
      final lastSync = forceFullHistory
          ? null
          : await DatabaseService.instance.getSetting(
              HealthDashboardTool.config.id,
              _healthConnectLastSyncKey,
            );
      final start = lastSync == null
          ? DateTime.utc(1970)
          : DateTime.fromMillisecondsSinceEpoch(
              int.parse(lastSync),
            ).subtract(const Duration(days: 1));
      final fetchedRecords = await _healthConnectCollector.collect(
        start: start,
        onProgress: _onCollectionProgress,
      );
      int savedCount = 0;
      for (final record in fetchedRecords) {
        await HealthDatabase.instance.upsertCollected(record);
        savedCount++;
        if (savedCount % 50 == 0 || savedCount == fetchedRecords.length) {
          _onCollectionProgress(
            'Saving to database ($savedCount / ${fetchedRecords.length})...',
            savedCount,
          );
        }
      }
      _onCollectionProgress(
        'Refreshing health dashboard...',
        fetchedRecords.length,
      );
      await DatabaseService.instance.setSetting(
        HealthDashboardTool.config.id,
        _healthConnectLastSyncKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Health Connect sync failed: $e');
    } finally {
      await lease?.release();
      isCollecting = false;
      collectionStatus = null;
      notifyListeners();
    }
  }

  Future<void> repairHealthConnectCache() async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    collectionStatus = 'Purging local cache...';
    collectedRecordCount = 0;
    notifyListeners();
    WakeLockLease? lease;
    try {
      lease = await PowerWakeLockService.acquireFull();
      await HealthDatabase.instance.purgeHealthConnectCache();
      final fetchedRecords = await _healthConnectCollector.collect(
        start: DateTime.utc(1970),
        onProgress: _onCollectionProgress,
      );
      int savedCount = 0;
      for (final record in fetchedRecords) {
        await HealthDatabase.instance.upsertCollected(record);
        savedCount++;
        if (savedCount % 50 == 0 || savedCount == fetchedRecords.length) {
          _onCollectionProgress(
            'Saving to database ($savedCount / ${fetchedRecords.length})...',
            savedCount,
          );
        }
      }
      _onCollectionProgress(
        'Refreshing health dashboard...',
        fetchedRecords.length,
      );
      await DatabaseService.instance.setSetting(
        HealthDashboardTool.config.id,
        _healthConnectLastSyncKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      debugPrint('[HealthDashboard] Health Connect repair failed: $e');
    } finally {
      await lease?.release();
      isCollecting = false;
      collectionStatus = null;
      notifyListeners();
    }
  }

  Future<void> refreshOnOpen(AppState appState) async {
    if (isCollecting) return;
    isCollecting = true;
    notifyListeners();
    try {
      for (final record in await _treadmillCollector.collect()) {
        await HealthDatabase.instance.upsertCollected(record);
      }
      if (autoHealthConnectSync) {
        final lastSync = await DatabaseService.instance.getSetting(
          HealthDashboardTool.config.id,
          _healthConnectLastSyncKey,
        );
        final start = lastSync == null
            ? DateTime.now().subtract(const Duration(days: 7))
            : DateTime.fromMillisecondsSinceEpoch(
                int.parse(lastSync),
              ).subtract(const Duration(days: 1));
        for (final record in await _healthConnectCollector.collect(
          start: start,
        )) {
          await HealthDatabase.instance.upsertCollected(record);
        }
        await DatabaseService.instance.setSetting(
          HealthDashboardTool.config.id,
          _healthConnectLastSyncKey,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
      if (appState.syncEnabled && !appState.isSyncing) {
        try {
          await appState.syncWithBackend([HealthDashboardSyncDelegate()]);
        } catch (e) {
          debugPrint('[HealthDashboard] Open sync failed: $e');
        }
      }
      await _reloadRecords();
    } catch (e) {
      debugPrint('[HealthDashboard] Open sync failed: $e');
    } finally {
      isCollecting = false;
      notifyListeners();
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
      .where((record) => record.type == 'workout.health_connect')
      .toList();

  List<HealthRecord> get allHealthData =>
      records.where((record) => record.type.startsWith('health.')).toList();

  List<HealthRecord> get workouts =>
      [...treadmillWorkouts, ...healthConnectWorkouts]
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  List<HealthRecord> get effectiveWorkouts => [
    ...treadmillWorkouts,
    ...healthConnectWorkouts.where(
      (record) => !treadmillWorkouts.any(
        (local) => _isPublishedTreadmillCopy(local, record),
      ),
    ),
  ];

  List<HealthRecord> workoutRecordsOnDay(DateTime day) {
    final treadmill = treadmillWorkouts
        .where((record) => _isOnDay(record, day))
        .toList();
    final healthConnect = healthConnectWorkouts
        .where((record) => _isOnDay(record, day))
        .where(
          (record) => !treadmill.any(
            (local) => _isPublishedTreadmillCopy(local, record),
          ),
        )
        .toList();
    return [...treadmill, ...healthConnect]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<List<HealthRecord>> workoutRecordsForDay(DateTime day) async {
    final dayRecords = await HealthDatabase.instance.recordsOnDay(day);
    final treadmill = dayRecords
        .where(
          (record) =>
              showTreadmillWorkouts && record.type == 'workout.treadmill',
        )
        .toList();
    final healthConnect = dayRecords
        .where((record) => record.type == 'workout.health_connect')
        .where(
          (record) => !treadmill.any(
            (local) => _isPublishedTreadmillCopy(local, record),
          ),
        )
        .toList();
    return [...treadmill, ...healthConnect]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  bool _isPublishedTreadmillCopy(
    HealthRecord treadmill,
    HealthRecord healthConnect,
  ) {
    final clientRecordId = healthConnect.value['clientRecordId'] as String?;
    if (clientRecordId != null &&
        clientRecordId ==
            '$treadmillHealthConnectClientIdPrefix${treadmill.sourceRecordId}:exercise') {
      return true;
    }
    final startDiff = (treadmill.startTime - healthConnect.startTime).abs();
    final endDiff = (treadmill.endTime - healthConnect.endTime).abs();
    if (startDiff < 120000 && endDiff < 120000) {
      return true;
    }
    final overlapStart = max(treadmill.startTime, healthConnect.startTime);
    final overlapEnd = min(treadmill.endTime, healthConnect.endTime);
    final overlapMs = overlapEnd - overlapStart;
    if (overlapMs > 0) {
      final treadmillDuration = max(1, treadmill.endTime - treadmill.startTime);
      final hcDuration = max(
        1,
        healthConnect.endTime - healthConnect.startTime,
      );
      if (overlapMs / min(treadmillDuration, hcDuration) > 0.8) {
        return true;
      }
    }
    return false;
  }

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
        .map((record) => metricValue(record, key))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    if (type == 'sleep.session') return values.reduce(max);
    if (sum) return values.reduce((a, b) => a + b);
    return values.reduce((a, b) => a + b) / values.length;
  });

  List<double?> workoutMetricValues(String key) =>
      List<double?>.generate(7, (index) {
        final values = workoutRecordsOnDay(_dayAt(index))
            .map((record) => metricValue(record, key))
            .whereType<double>()
            .toList();
        if (values.isEmpty) return null;
        return values.reduce((a, b) => a + b);
      });

  HealthRecord? metricRecordOnDay({
    required String type,
    required String key,
    required DateTime day,
    required bool workoutMetric,
  }) {
    final candidates =
        (workoutMetric ? workoutRecordsOnDay(day) : recordsOnDay(type, day))
            .where((record) => (metricValue(record, key) ?? 0) > 0)
            .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((first, second) {
      final firstIsTreadmill = first.type == 'workout.treadmill';
      final secondIsTreadmill = second.type == 'workout.treadmill';
      if (firstIsTreadmill != secondIsTreadmill) {
        return firstIsTreadmill ? -1 : 1;
      }
      final valueOrder = (metricValue(second, key) ?? 0).compareTo(
        metricValue(first, key) ?? 0,
      );
      return valueOrder != 0
          ? valueOrder
          : second.endTime.compareTo(first.endTime);
    });
    return candidates.first;
  }

  double? metricValue(HealthRecord record, String key) {
    if (record.type == 'sleep.session' && key == 'durationMinutes') {
      return Duration(
        milliseconds: record.endTime - record.startTime,
      ).inMinutes.toDouble();
    }
    if (key == 'durationMinutes' && record.type.startsWith('workout.')) {
      final milliseconds = record.endTime - record.startTime;
      return record.type == 'workout.treadmill'
          ? ((record.value['durationSeconds'] as num?)?.toDouble() ?? 0) / 60
          : milliseconds / Duration.millisecondsPerMinute;
    }
    return (record.value[key] as num?)?.toDouble();
  }

  bool isNap(HealthRecord record) {
    final title = (record.value['title'] as String?)?.toLowerCase() ?? '';
    return title.contains('nickerchen') || title.contains('nap');
  }

  int get todaySteps {
    final dayRecords = recordsOnDay('activity.steps', DateTime.now());
    final deduplicated = _deduplicateIntervals(dayRecords, 'count');
    return deduplicated.fold(
      0,
      (sum, record) => sum + ((record.value['count'] as num?) ?? 0).round(),
    );
  }

  double? get latestWeightKg => _latestNumeric('body.weight', 'kilograms');

  double? get latestRestingHeartRate => _latestNumeric('heart.resting', 'bpm');

  double? get latestHrv =>
      _latestNumeric('health.heart_rate_variability_rmssd', 'rmssdMs');

  double? get latestSpO2 =>
      _latestNumeric('health.oxygen_saturation', 'percent');

  double? get latestRespiratoryRate =>
      _latestNumeric('health.respiratory_rate', 'respiratoryRate');

  double? get latestBodyFat =>
      _latestNumeric('health.body_fat_percentage', 'percent');

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

  List<double> get weeklyDistanceKm =>
      workoutMetricValues('distanceKm').map((value) => value ?? 0).toList();

  double get selectedWeekDistanceKm =>
      weeklyDistanceKm.fold(0, (a, b) => a + b);

  int get selectedWeekCalories => workoutMetricValues(
    'calories',
  ).whereType<double>().fold(0, (sum, value) => sum + value.round());

  int get totalSteps {
    final allSteps = recordsOfType('activity.steps');
    final deduplicated = _deduplicateIntervals(allSteps, 'count');
    return deduplicated.fold(
      0,
      (sum, record) => sum + ((record.value['count'] as num?) ?? 0).round(),
    );
  }

  int get selectedWeekSteps => List<int>.generate(7, (index) {
    final dayRecords = recordsOnDay('activity.steps', _dayAt(index));
    final deduplicated = _deduplicateIntervals(dayRecords, 'count');
    return deduplicated.fold(
      0,
      (sum, record) => sum + ((record.value['count'] as num?) ?? 0).round(),
    );
  }).fold(0, (sum, value) => sum + value);

  List<HealthRecord> _deduplicateIntervals(
    List<HealthRecord> input,
    String valueKey,
  ) {
    if (input.length <= 1) return input;
    final sorted = List<HealthRecord>.from(input)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final result = <HealthRecord>[];

    for (final record in sorted) {
      if (result.isEmpty) {
        result.add(record);
        continue;
      }
      final last = result.last;
      final overlapStart = max(last.startTime, record.startTime);
      final overlapEnd = min(last.endTime, record.endTime);
      final overlapMs = overlapEnd - overlapStart;

      if (overlapMs > 0) {
        final lastDuration = max(1, last.endTime - last.startTime);
        final recDuration = max(1, record.endTime - record.startTime);
        final overlapRatio = overlapMs / min(lastDuration, recDuration);

        if (overlapRatio > 0.5) {
          final lastVal = (metricValue(last, valueKey) ?? 0);
          final recVal = (metricValue(record, valueKey) ?? 0);
          if (record.sourceName?.contains('tool_lab') == true ||
              recVal > lastVal) {
            result[result.length - 1] = record;
          }
          continue;
        }
      }
      result.add(record);
    }
    return result;
  }

  int get selectedWeekDurationSeconds => workoutMetricValues(
    'durationMinutes',
  ).whereType<double>().fold(0, (sum, value) => sum + (value * 60).round());

  List<double?> get weeklyHeartRate => List<double?>.generate(7, (index) {
    final day = _dayAt(index);
    final values = <double>[
      for (final workout in workoutRecordsOnDay(day))
        if (((workout.value['averageHeartRate'] as num?) ?? 0) > 0)
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

  double get totalDistanceKm => effectiveWorkouts.fold(
    0,
    (sum, record) => sum + ((record.value['distanceKm'] as num?) ?? 0),
  );

  int get totalCalories => effectiveWorkouts.fold(
    0,
    (sum, record) => sum + ((record.value['calories'] as num?) ?? 0).round(),
  );

  int get totalDurationSeconds => effectiveWorkouts.fold(
    0,
    (sum, record) =>
        sum +
        (record.type == 'workout.treadmill'
            ? ((record.value['durationSeconds'] as num?) ?? 0).round()
            : (record.endTime - record.startTime) ~/
                  Duration.millisecondsPerSecond),
  );
}

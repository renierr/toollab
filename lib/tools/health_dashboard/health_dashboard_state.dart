import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/background_work_lease.dart';

import 'collectors/health_connect_diff.dart';
import 'collectors/health_connect_discovery.dart';
import 'collectors/health_connect_importer.dart';
import 'store/health_metric_catalog.dart';
import 'store/health_queries.dart';
import 'store/health_store.dart';
import '../treadmill_control/treadmill_health_connect_publisher.dart';
import 'config.dart';
import 'health_record.dart';
import 'health_record_values.dart';

class HealthDashboardState extends ChangeNotifier {
  static const _autoHealthConnectSyncKey = 'auto_health_connect_sync';
  List<HealthRecord> records = [];
  bool isLoading = true;
  bool isCollecting = false;
  bool isImportingBackup = false;
  bool isExportingBackup = false;
  bool autoHealthConnectSync = false;

  /// True when the last Health Connect action stopped because nothing is
  /// granted. The UI offers the Health Connect screen rather than reporting a
  /// successful import of zero records.
  bool permissionMissing = false;
  int trendDayOffset = 0;
  String? error;
  double allTimeDistanceKm = 0;
  int allTimeCalories = 0;
  int allTimeDurationSeconds = 0;
  int allTimeSteps = 0;
  int allTimeWorkouts = 0;
  Map<String, int> _dailySteps = {};
  Map<String, double> _dailyHeartRate = {};

  String? collectionStatus;
  int collectedRecordCount = 0;
  int backupImportProcessedCount = 0;
  int backupImportTotalCount = 0;
  int backupExportProcessedCount = 0;
  int backupExportTotalCount = 0;

  BackgroundWorkLease? _importWork;

  void _onCollectionProgress(String status, int count) {
    collectionStatus = status;
    collectedRecordCount = count;
    _importWork?.update(count > 0 ? '$status ($count)' : status);
    notifyListeners();
  }

  Future<BackgroundWorkLease> _beginBackgroundWork(
    String text, {
    String title = 'Health Dashboard import',
  }) async {
    final work = await BackgroundWorkLease.acquire(
      title: title,
      text: text,
      logPrefix: 'HealthDashboard',
    );
    _importWork = work;
    return work;
  }

  Future<void> _endBackgroundWork(BackgroundWorkLease? work) async {
    _importWork = null;
    await work?.release();
  }

  HealthDashboardState() {
    load();
  }

  Future<void> load({bool showLoading = true}) async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    if (kDebugMode) debugLog('[HealthDashboard] Starting dashboard load');
    if (showLoading && records.isEmpty) {
      isLoading = true;
      notifyListeners();
    }
    error = null;
    try {
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Load failed: $e');
    } finally {
      isLoading = false;
      if (kDebugMode) {
        debugLog(
          '[HealthDashboard] Dashboard load completed in '
          '${stopwatch!.elapsedMilliseconds}ms',
        );
      }
      notifyListeners();
    }
  }

  /// Re-reads the stored data without touching Health Connect. Cheap enough to
  /// run whenever the dashboard comes back into view, since anything the
  /// settings screen did wrote to the store, not to this object.
  Future<void> reloadStoredData() async {
    if (isCollecting) return;
    await _reloadRecords();
    notifyListeners();
  }

  Future<void> _reloadRecords() async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    if (kDebugMode) debugLog('[HealthDashboard] Loading dashboard records');
    final start = _dayAt(0);
    final end = _dayAt(6).add(const Duration(days: 1));
    final results = await Future.wait([
      HealthQueries.instance.dashboardRecords(start: start, end: end),
      HealthQueries.instance.latestDashboardRecords(),
      HealthQueries.instance.allTimeWorkoutSummary(),
      HealthQueries.instance.allTimeSteps(),
      HealthQueries.instance.dailyStepTotals(start: start, end: end),
      HealthQueries.instance.dailyHeartRateAverages(start: start, end: end),
    ]);
    final weekRecords = results[0] as List<HealthRecord>;
    final latestRecords = results[1] as List<HealthRecord>;
    final summary = results[2] as Map<String, num>;
    records = [
      ...{
        for (final record in [...weekRecords, ...latestRecords])
          record.id: record,
      }.values,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
    allTimeDistanceKm = summary['distance']!.toDouble();
    allTimeCalories = summary['calories']!.round();
    allTimeDurationSeconds = summary['duration']!.round();
    allTimeWorkouts = summary['workouts']!.toInt();
    allTimeSteps = results[3] as int;
    _dailySteps = results[4] as Map<String, int>;
    _dailyHeartRate = results[5] as Map<String, double>;
    autoHealthConnectSync =
        await DatabaseService.instance.getSetting(
          HealthDashboardTool.config.id,
          _autoHealthConnectSyncKey,
        ) ==
        'true';
    if (kDebugMode) {
      debugLog(
        '[HealthDashboard] Dashboard data ready: ${records.length} records in '
        '${stopwatch!.elapsedMilliseconds}ms',
      );
    }
  }

  /// Pull-to-refresh and the toolbar refresh button. Re-reads what is stored and
  /// pushes any treadmill sessions that have not reached Health Connect yet; it
  /// deliberately does not import, so refreshing stays instant.
  Future<void> refresh() async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    notifyListeners();
    try {
      // The user asked for this one, so it skips the publisher's throttle.
      await TreadmillHealthConnectPublisher.instance.publishPendingSessions(
        force: true,
      );
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Refresh failed: $e');
    } finally {
      isCollecting = false;
      notifyListeners();
    }
  }

  Future<void> refreshOnOpen() async {
    if (isCollecting) return;
    // Show what is already stored before any Health Connect work, so opening the
    // tool is never gated on an import.
    await _reloadRecords();
    isCollecting = true;
    notifyListeners();
    BackgroundWorkLease? work;
    try {
      // Treadmill workouts are no longer read out of Treadmill Control's
      // database. That tool publishes them to Health Connect, so they arrive
      // here as ordinary exercise sessions written by our own package - one
      // source of truth instead of two copies to reconcile.
      await TreadmillHealthConnectPublisher.instance.publishPendingSessions();
      // Change-token sync, not a re-import: it fetches only what Health Connect
      // reports as changed, so opening the tool stays cheap even with a decade
      // of history stored. It can still run long after a break, so it gets the
      // CPU lease - the publish above brings its own.
      if (autoHealthConnectSync) {
        work = await _beginBackgroundWork(
          'Syncing...',
          title: 'Health Dashboard sync',
        );
        await _diff.sync();
      }
      await _reloadRecords();
    } catch (e) {
      errorLog('[HealthDashboard] Open refresh failed: $e');
    } finally {
      await _endBackgroundWork(work);
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

  // --- selection, full import, incremental sync ------------------------------

  final _importer = const HealthConnectImporter();
  final _discovery = const HealthConnectDiscovery();
  final _diff = const HealthConnectDiff();

  List<HealthTypeState> healthTypes = [];
  final Map<String, List<HealthDiscoveredApp>> discoveredApps = {};
  Map<String, int> storeRowCounts = const {};
  List<HealthAppState> healthApps = [];
  Map<int, int> appRowCounts = const {};

  int get enabledTypeCount => healthTypes.where((type) => type.enabled).length;

  Future<void> loadSelection() async {
    healthTypes = await HealthStore.instance.types();
    for (final type in healthTypes) {
      discoveredApps[type.type] = await HealthStore.instance.discoveredApps(
        type.type,
      );
    }
    healthApps = await HealthStore.instance.apps();
    storeRowCounts = await HealthStore.instance.rowCounts();
    notifyListeners();
  }

  /// Counting a writer's rows scans the dense tables' indexes, so the app list
  /// paints first and fills its counts in afterwards.
  Future<void> loadAppRowCounts() async {
    appRowCounts = await HealthStore.instance.appRowCounts();
    notifyListeners();
  }

  Future<void> setTypeEnabled(String type, bool enabled) async {
    await HealthStore.instance.setTypeEnabled(type, enabled);
    await loadSelection();
  }

  /// Per-type source selection. This is a **pull** filter: switching a source
  /// off stops it being read for this type and drops it out of the aggregates,
  /// but keeps the rows it already contributed so switching it back on is free.
  Future<void> setSourceEnabled({
    required String type,
    required String package,
    required bool enabled,
  }) async {
    await HealthStore.instance.setTypeAppEnabled(
      type: type,
      package: package,
      enabled: enabled,
    );
    // A type that already finished importing would otherwise be skipped, so the
    // newly allowed writer's history would never be read.
    if (enabled) await HealthStore.instance.resetTypeHistory([type]);
    await loadSelection();
  }

  /// Global source switch. Off means the writer is neither pulled nor counted
  /// anywhere, while its stored rows stay put - see [deleteAppData] to reclaim
  /// the space.
  Future<void> setAppEnabled(String package, bool enabled) async {
    await HealthStore.instance.setAppEnabled(package, enabled);
    if (enabled) {
      await HealthStore.instance.resetTypeHistory(
        healthTypes.map((type) => type.type),
      );
    }
    await loadSelection();
    await load(showLoading: false);
  }

  /// Writer priority, best first. Decides which single source a day's totals are
  /// computed from, and which side of a mirrored session survives.
  Future<void> setAppOrder(List<String> packages) async {
    await HealthStore.instance.setAppOrder(packages);
    await loadSelection();
    await load(showLoading: false);
  }

  /// Explicitly drops a writer's stored rows and shrinks the database file.
  Future<void> deleteAppData(String package) async {
    if (isCollecting) return;
    isCollecting = true;
    collectionStatus = 'Removing $package...';
    notifyListeners();
    try {
      await HealthStore.instance.deleteApp(package, vacuum: true);
      await loadSelection();
      await loadAppRowCounts();
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Deleting app data failed: $e');
    } finally {
      isCollecting = false;
      collectionStatus = null;
      notifyListeners();
    }
  }

  /// Destructive housekeeping: drops what nothing can read any more and rewrites
  /// the database file. Callers confirm first.
  Future<HealthPruneResult?> pruneUnusedData() async {
    if (isCollecting) return null;
    isCollecting = true;
    error = null;
    notifyListeners();
    BackgroundWorkLease? work;
    try {
      // A rebuild plus VACUUM over a full history runs for minutes; without the
      // CPU lease the device can suspend the app halfway through it.
      work = await _beginBackgroundWork(
        'Cleaning up...',
        title: 'Health Dashboard cleanup',
      );
      final result = await HealthStore.instance.pruneUnused();
      await loadSelection();
      await loadAppRowCounts();
      await _reloadRecords();
      return result;
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Pruning unused data failed: $e');
      return null;
    } finally {
      await _endBackgroundWork(work);
      isCollecting = false;
      notifyListeners();
    }
  }

  Future<void> runDiscovery() async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    permissionMissing = false;
    collectionStatus = 'Scanning Health Connect...';
    collectedRecordCount = 0;
    notifyListeners();
    BackgroundWorkLease? work;
    try {
      work = await _beginBackgroundWork('Scanning...');
      if (!await _importer.requestAccess()) {
        permissionMissing = true;
        return;
      }
      await _discovery.run(onProgress: _onCollectionProgress);
      await loadSelection();
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Discovery failed: $e');
    } finally {
      await _endBackgroundWork(work);
      isCollecting = false;
      collectionStatus = null;
      notifyListeners();
    }
  }

  /// Full history for every enabled type. [restart] discards stored progress and
  /// re-reads from 1970 instead of resuming.
  Future<void> importIntoStore({bool restart = false}) async {
    if (isCollecting) return;
    isCollecting = true;
    error = null;
    permissionMissing = false;
    collectionStatus = 'Starting import...';
    collectedRecordCount = 0;
    notifyListeners();
    BackgroundWorkLease? work;
    try {
      work = await _beginBackgroundWork('Starting...');
      if (!await _importer.requestAccess()) {
        permissionMissing = true;
        return;
      }
      if (restart) await HealthStore.instance.clearImportedData();
      await _importer.import(
        start: DateTime.utc(1970),
        restart: restart,
        onProgress: _onCollectionProgress,
      );
      // A full import is the moment a baseline is worth taking: every later open
      // then only has to fetch changes.
      await _diff.sync();
      await loadSelection();
      // The dashboard reads from memory, so without this it keeps showing what
      // was loaded before the import until the page itself is rebuilt.
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Store import failed: $e');
    } finally {
      await _endBackgroundWork(work);
      isCollecting = false;
      collectionStatus = null;
      notifyListeners();
    }
  }

  /// Change-token sync. Cheap enough to run on open: it fetches only what moved.
  Future<HealthDiffResult> syncChanges() async {
    if (isCollecting) return const HealthDiffResult();
    isCollecting = true;
    error = null;
    permissionMissing = false;
    notifyListeners();
    BackgroundWorkLease? work;
    try {
      work = await _beginBackgroundWork(
        'Syncing...',
        title: 'Health Dashboard sync',
      );
      if (!await _importer.requestAccess()) {
        permissionMissing = true;
        return const HealthDiffResult();
      }
      final result = await _diff.sync();
      if (result.needsFullImport) {
        errorLog(
          '[HealthDashboard] Sync token invalid; a full import is required',
        );
      }
      await loadSelection();
      if (result.upserted > 0 || result.deleted > 0) await _reloadRecords();
      return result;
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Change sync failed: $e');
      return const HealthDiffResult();
    } finally {
      await _endBackgroundWork(work);
      isCollecting = false;
      notifyListeners();
    }
  }

  Future<String> exportBackup() async {
    if (isExportingBackup) throw StateError('Health backup export is running.');
    isExportingBackup = true;
    backupExportProcessedCount = 0;
    backupExportTotalCount = 0;
    notifyListeners();
    BackgroundWorkLease? work;
    try {
      work = await _beginBackgroundWork('Starting...');
      return await HealthStore.instance.exportBackup(
        onProgress: (processed, total) {
          backupExportProcessedCount = processed;
          backupExportTotalCount = total;
          notifyListeners();
        },
      );
    } finally {
      await _endBackgroundWork(work);
      isExportingBackup = false;
      notifyListeners();
    }
  }

  Future<int> importBackup(String path) async {
    if (isImportingBackup) return 0;
    isImportingBackup = true;
    backupImportProcessedCount = 0;
    backupImportTotalCount = 0;
    notifyListeners();
    try {
      final imported = await HealthStore.instance.importBackup(
        path,
        onProgress: (processed, total) {
          backupImportProcessedCount = processed;
          backupImportTotalCount = total;
          notifyListeners();
        },
      );
      await load(showLoading: false);
      return imported;
    } finally {
      isImportingBackup = false;
      notifyListeners();
    }
  }

  // Treadmill workouts arrive as ordinary Health Connect exercise sessions
  // written by our own package, so there is no second local copy to reconcile
  // and no treadmill-specific dedup left. Anything published by the treadmill
  // tool is simply a workout with our package as its source.
  List<HealthRecord> get workouts =>
      records
          .where((record) => record.type == HealthQueries.workoutType)
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  List<HealthRecord> get effectiveWorkouts => workouts;

  List<HealthRecord> get allHealthData =>
      records.where((record) => record.type.startsWith('health.')).toList();

  List<HealthRecord> workoutRecordsOnDay(DateTime day) =>
      workouts.where((record) => _isOnDay(record, day)).toList();

  Future<List<HealthRecord>> workoutRecordsForDay(DateTime day) async {
    final dayRecords = await HealthQueries.instance.recordsOnDay(day);
    return dayRecords
        .where((record) => record.type == HealthQueries.workoutType)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Source choice happens at pull time now - only selected writers are ever
  /// imported - so there is no display-time preference left to apply and
  /// [preferredOnly] is accepted only to keep call sites unchanged.
  List<HealthRecord> recordsOfType(String type, {bool preferredOnly = false}) =>
      records.where((record) => record.type == type).toList();

  DateTime get selectedDay => _dayAt(6);

  DateTime trendDayAt(int index) => _dayAt(index);

  List<HealthRecord> recordsOnDay(String type, DateTime day) =>
      recordsOfType(type).where((record) => _isOnDay(record, day)).toList();

  Future<void> selectDay(DateTime day) async {
    final today = DateTime.now();
    trendDayOffset = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    notifyListeners();
    await _reloadTrendWindow();
  }

  Future<void> previousTrendDay() async {
    trendDayOffset--;
    notifyListeners();
    await _reloadTrendWindow();
  }

  Future<void> nextTrendDay() async {
    if (trendDayOffset == 0) return;
    trendDayOffset++;
    notifyListeners();
    await _reloadTrendWindow();
  }

  Future<void> resetTrendDate() async {
    if (trendDayOffset == 0) return;
    trendDayOffset = 0;
    notifyListeners();
    await _reloadTrendWindow();
  }

  Future<void> _reloadTrendWindow() async {
    try {
      await _reloadRecords();
    } catch (e) {
      error = e.toString();
      errorLog('[HealthDashboard] Trend window load failed: $e');
    } finally {
      notifyListeners();
    }
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
      final valueOrder = (metricValue(second, key) ?? 0).compareTo(
        metricValue(first, key) ?? 0,
      );
      return valueOrder != 0
          ? valueOrder
          : second.endTime.compareTo(first.endTime);
    });
    return candidates.first;
  }

  double? metricValue(HealthRecord record, String key) =>
      healthRecordValue(record, key);

  bool isNap(HealthRecord record) => healthRecordIsNap(record);

  int get todaySteps {
    return _dailySteps[_dayKey(DateTime.now())] ?? 0;
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
    return _dailySteps[_dayKey(_dayAt(index))] ?? 0;
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
    return _dailyHeartRate[_dayKey(day)];
  });

  /// Heart-rate curve inside a session, read straight from the dense table as a
  /// bounded range seek. It no longer scans the loaded week's records, so a
  /// drilldown works for any session in history, not just a recent one.
  Future<List<Map<String, dynamic>>> heartRateSamplesDuring(
    HealthRecord session,
  ) async {
    final points = await HealthStore.instance.pointsInRange(
      metric: HealthMetrics.heartRate,
      from: session.startTime,
      to: session.endTime,
    );
    return [
      for (final point in points) {'time': point.t, 'bpm': point.v},
    ];
  }

  DateTime _dayAt(int index) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: trendDayOffset - 6 + index));
  }

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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
        (record.endTime - record.startTime) ~/ Duration.millisecondsPerSecond,
  );
}

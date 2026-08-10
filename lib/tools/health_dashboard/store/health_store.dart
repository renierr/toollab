import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';
import 'health_metric_catalog.dart';
import 'health_rows.dart';
import 'health_schema.dart';

/// A day's reduced value for one metric, straight out of `health_daily`.
class HealthDailyValue {
  final int day;
  final double? total;
  final double? avg;
  final double? lo;
  final double? hi;
  final int n;

  const HealthDailyValue({
    required this.day,
    required this.total,
    required this.avg,
    required this.lo,
    required this.hi,
    required this.n,
  });

  /// The number this metric is meant to be shown as.
  double? valueFor(HealthAggregation aggregation) => switch (aggregation) {
    HealthAggregation.total => total,
    HealthAggregation.average || HealthAggregation.latest => avg,
  };
}

class HealthSession {
  final int id;
  final int kind;
  final String? activity;
  final String? title;
  final String? notes;
  final int t0;
  final int t1;
  final String? package;
  final String origin;
  final String? clientId;
  final double? distanceKm;
  final double? calories;
  final int? steps;
  final double? avgHr;
  final double? maxHr;
  final double? avgSpeed;
  final double? maxSpeed;
  final int? asleepMin;

  const HealthSession({
    required this.id,
    required this.kind,
    required this.t0,
    required this.t1,
    required this.origin,
    this.activity,
    this.title,
    this.notes,
    this.package,
    this.clientId,
    this.distanceKm,
    this.calories,
    this.steps,
    this.avgHr,
    this.maxHr,
    this.avgSpeed,
    this.maxSpeed,
    this.asleepMin,
  });

  int get durationSeconds => (t1 - t0) ~/ 1000;
}

class HealthSessionPart {
  final int kind;
  final String? part;
  final int? t0;
  final int? t1;
  final double? v;

  const HealthSessionPart({
    required this.kind,
    this.part,
    this.t0,
    this.t1,
    this.v,
  });
}

/// A single measurement read back for a chart.
class HealthPoint {
  final int t;
  final double v;
  final double? v2;

  /// Writing app, so a list can show which source a measurement came from.
  final String? package;

  const HealthPoint(this.t, this.v, [this.v2, this.package]);
}

/// An interval value read back for a list or chart.
class HealthInterval {
  final int t0;
  final int t1;
  final double v;
  final String? package;

  const HealthInterval(this.t0, this.t1, this.v, [this.package]);
}

class HealthDiscoveredApp {
  final int appId;
  final String package;
  final bool enabled;
  final int count;
  final int? lastSeen;

  const HealthDiscoveredApp({
    required this.appId,
    required this.package,
    required this.enabled,
    required this.count,
    this.lastSeen,
  });
}

class HealthTypeState {
  final String type;
  final bool enabled;
  final bool historyDone;
  final int count;

  const HealthTypeState({
    required this.type,
    required this.enabled,
    required this.historyDone,
    required this.count,
  });
}

/// Typed store for the health dashboard. Owns the schema in [HealthSchema], the
/// dimension interning, the daily rollups and every read the UI performs.
class HealthStore {
  HealthStore._();

  static final HealthStore instance = HealthStore._();

  ToolDatabase? _database;
  Future<ToolDatabase>? _opening;

  final Map<String, int> _metricIds = {};
  final Map<String, int> _appIds = {};
  final Map<String, int> _textIds = {};
  final Map<int, String> _appPackages = {};
  final Map<int, String> _textValues = {};

  Future<ToolDatabase> _db() async {
    final existing = _database;
    if (existing != null) return existing;
    return _opening ??= _open();
  }

  /// This store is the only owner of the tool's schema, so there is exactly one
  /// `migrate()` caller. Two would race: whichever bumped the shared
  /// `_db_schema_version` first would make the other's DDL be skipped.
  Future<ToolDatabase> _open() async {
    final database = await DatabaseService.instance.getToolDatabase(
      HealthDashboardTool.config.id,
    );
    await _dropPreTypedSchema(database);
    await database.migrate(
      currentVersion: HealthSchema.version,
      onMigrate: (txn, oldVersion, newVersion) async {
        if (oldVersion < 1) await HealthSchema.create(txn);
      },
    );
    _database = database;
    await _loadDimensions(database);
    return database;
  }

  /// Tables from every schema that existed before the typed store, plus the
  /// settings that tracked their progress.
  static const _preTypedTables = [
    'records',
    'health_import_checkpoints',
    'health_duplicate_candidates',
    'health_session_details',
    'health_sessions',
    'health_metric_samples',
    'health_interval_metrics',
    'health_source_records',
    'health_sources',
    'health_backup_meta',
  ];

  /// One-time wipe of the pre-typed schema, so the tool restarts at version 1
  /// with the typed store as its only tables.
  ///
  /// Safe to lose: everything came from Health Connect and is re-importable, and
  /// treadmill workouts now live in Treadmill Control's own database and reach
  /// the dashboard by being published to Health Connect. Nothing here was the
  /// only copy of anything.
  ///
  /// Detected by the stored schema version rather than by probing for tables,
  /// because the old ladder had reached 10 and `migrate()` would otherwise skip
  /// straight past the fresh version 1.
  Future<void> _dropPreTypedSchema(ToolDatabase db) async {
    final rows = await db.executor.query(
      'tool_settings',
      columns: ['value'],
      where: 'tool_id = ? AND key = ?',
      whereArgs: [HealthDashboardTool.config.id, '_db_schema_version'],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final stored = int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
    if (stored <= HealthSchema.version) return;
    errorLog(
      '[HealthStore] Dropping pre-typed schema (was version $stored) and '
      'restarting at version ${HealthSchema.version}',
    );
    await db.transaction((txn) async {
      for (final table in [..._preTypedTables, ...HealthSchema.backupTables]) {
        await txn.execute('DROP TABLE IF EXISTS ${txn.nameTable(table)}');
      }
      // Import watermarks, sync cursors and per-type source preferences all
      // described data that no longer exists.
      await txn.executor.delete(
        'tool_settings',
        where:
            'tool_id = ? AND (key = ? OR key LIKE ? OR key LIKE ? OR key LIKE ?)',
        whereArgs: [
          HealthDashboardTool.config.id,
          '_db_schema_version',
          'sync_cursor_%',
          'source_preference_%',
          'health_connect_last_sync%',
        ],
      );
    });
  }

  void reset() {
    _database = null;
    _opening = null;
    _metricIds.clear();
    _appIds.clear();
    _textIds.clear();
    _appPackages.clear();
    _textValues.clear();
  }

  Future<void> _loadDimensions(ToolDatabase db) async {
    for (final row in await db.query(HealthSchema.metric)) {
      _metricIds[row['key'] as String] = row['id'] as int;
    }
    for (final row in await db.query(HealthSchema.app)) {
      final id = row['id'] as int;
      final package = row['package'] as String;
      _appIds[package] = id;
      _appPackages[id] = package;
    }
    for (final row in await db.query(HealthSchema.text)) {
      final id = row['id'] as int;
      final value = row['value'] as String;
      _textIds[value] = id;
      _textValues[id] = value;
    }
  }

  Future<int> _metricId(ToolDatabaseExecutor db, String key) async {
    final cached = _metricIds[key];
    if (cached != null) return cached;
    final spec = HealthMetrics.spec(key);
    if (spec == null) {
      throw ArgumentError('Unknown health metric: $key');
    }
    await db.insert(HealthSchema.metric, {
      'key': spec.key,
      'unit': spec.unit,
      'agg': spec.aggregation.index,
      'shape': spec.shape.index,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query(
      HealthSchema.metric,
      columns: ['id'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    final id = rows.single['id'] as int;
    _metricIds[key] = id;
    return id;
  }

  Future<int> _appId(ToolDatabaseExecutor db, String package) async {
    final cached = _appIds[package];
    if (cached != null) return cached;
    await db.insert(HealthSchema.app, {
      'package': package,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query(
      HealthSchema.app,
      columns: ['id'],
      where: 'package = ?',
      whereArgs: [package],
      limit: 1,
    );
    final id = rows.single['id'] as int;
    _appIds[package] = id;
    _appPackages[id] = package;
    return id;
  }

  Future<int?> _textId(ToolDatabaseExecutor db, String? value) async {
    if (value == null || value.isEmpty) return null;
    final cached = _textIds[value];
    if (cached != null) return cached;
    await db.insert(HealthSchema.text, {
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query(
      HealthSchema.text,
      columns: ['id'],
      where: 'value = ?',
      whereArgs: [value],
      limit: 1,
    );
    final id = rows.single['id'] as int;
    _textIds[value] = id;
    _textValues[id] = value;
    return id;
  }

  /// Local midnight of [millis] as epoch millis. Used as the `health_daily` key
  /// so a day always means the user's day, and so recomputing a day is a range
  /// derived by calendar arithmetic rather than a fixed 24 hours.
  static int dayKey(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  }

  /// Half-open bounds of the day [key] covers. Built with `DateTime(y, m, d+1)`
  /// rather than `+ Duration(days: 1)`, which would be 24 hours and land an hour
  /// early or late across a DST change.
  static (int, int) dayBounds(int key) {
    final start = DateTime.fromMillisecondsSinceEpoch(key);
    final next = DateTime(start.year, start.month, start.day + 1);
    return (key, next.millisecondsSinceEpoch);
  }

  static int dayAfter(int key, int days) {
    final date = DateTime.fromMillisecondsSinceEpoch(key);
    return DateTime(
      date.year,
      date.month,
      date.day + days,
    ).millisecondsSinceEpoch;
  }

  /// Writes a page of mapped records and refreshes only the daily rollups the
  /// page touched. One transaction, so an interrupted import never leaves the
  /// rollups disagreeing with the facts.
  Future<int> writeRecords(Iterable<HealthMappedRecord> records) async {
    final db = await _db();
    var written = 0;
    // (metricId, dayKey) pairs, so a page spanning three days recomputes three
    // days rather than the whole metric.
    final touched = <int, Set<int>>{};
    await db.transaction((txn) async {
      final batch = txn.batch();
      var queued = 0;
      for (final record in records) {
        if (record.isEmpty) continue;
        final appId = await _appId(txn, record.package);
        for (final row in record.points) {
          final metricId = await _metricId(txn, row.metric);
          batch.insert(HealthSchema.point, {
            'metric': metricId,
            't': row.t,
            'v': row.v,
            'v2': row.v2,
            'app': appId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          queued++;
          (touched[metricId] ??= <int>{}).add(dayKey(row.t));
        }
        for (final row in record.intervals) {
          final metricId = await _metricId(txn, row.metric);
          batch.insert(HealthSchema.interval, {
            'metric': metricId,
            't0': row.t0,
            't1': row.t1,
            'v': row.v,
            'app': appId,
            'origin': row.origin,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          queued++;
          (touched[metricId] ??= <int>{}).add(dayKey(row.t0));
        }
        written += record.rowCount;
      }
      // Sessions need their generated id, so they cannot ride the batch.
      if (queued > 0) await batch.commit(noResult: true);
      for (final record in records) {
        final session = record.session;
        if (session == null) continue;
        await _writeSession(txn, await _appId(txn, record.package), session);
      }
      await _refreshDaily(txn, touched);
    });
    return written;
  }

  Future<void> _writeSession(
    ToolDatabaseExecutor db,
    int appId,
    HealthSessionRow row,
  ) async {
    // A session already stored for this exact range and kind by another app is
    // a mirror of the same activity - Google Fit republishing a watch's workout.
    // Keeping the first writer is vendor-neutral and costs one index seek.
    final existing = await db.query(
      HealthSchema.session,
      columns: ['id', 'origin'],
      where: 'kind = ? AND t0 = ? AND t1 = ?',
      whereArgs: [row.kind, row.t0, row.t1],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.single['origin'] != row.origin) return;
    final values = {
      'kind': row.kind,
      'activity': await _textId(db, row.activity),
      'title': await _textId(db, row.title),
      'notes': row.notes,
      't0': row.t0,
      't1': row.t1,
      'app': appId,
      'origin': row.origin,
      'client_id': row.clientId,
      'distance_km': row.distanceKm,
      'calories': row.calories,
      'steps': row.steps,
      'avg_hr': row.avgHr,
      'max_hr': row.maxHr,
      'avg_speed': row.avgSpeed,
      'max_speed': row.maxSpeed,
      'asleep_min': row.asleepMin,
    };
    final int sessionId;
    if (existing.isNotEmpty) {
      sessionId = existing.single['id'] as int;
      await db.update(
        HealthSchema.session,
        values,
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await db.delete(
        HealthSchema.sessionPart,
        where: 'session = ?',
        whereArgs: [sessionId],
      );
    } else {
      sessionId = await db.insert(HealthSchema.session, values);
    }
    if (row.parts.isEmpty) return;
    final batch = db.batch();
    for (var index = 0; index < row.parts.length; index++) {
      final part = row.parts[index];
      batch.insert(HealthSchema.sessionPart, {
        'session': sessionId,
        'seq': index,
        'kind': part.kind,
        'part': await _textId(db, part.part),
        't0': part.t0,
        't1': part.t1,
        'v': part.v,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _refreshDaily(
    ToolDatabaseExecutor db,
    Map<int, Set<int>> touched,
  ) async {
    if (touched.isEmpty) return;
    final points = db.nameTable(HealthSchema.point);
    final intervals = db.nameTable(HealthSchema.interval);
    final shapes = <int, HealthMetricShape>{};
    for (final entry in _metricIds.entries) {
      final spec = HealthMetrics.spec(entry.key);
      if (spec != null) shapes[entry.value] = spec.shape;
    }
    final batch = db.batch();
    var queued = 0;
    for (final entry in touched.entries) {
      final metricId = entry.key;
      final isInterval = shapes[metricId] == HealthMetricShape.interval;
      final table = isInterval ? intervals : points;
      final column = isInterval ? 't0' : 't';
      for (final day in entry.value) {
        final (start, end) = dayBounds(day);
        final rows = await db.rawQuery(
          'SELECT SUM(v) AS total, AVG(v) AS avg, MIN(v) AS lo, MAX(v) AS hi, '
          'COUNT(*) AS n FROM $table '
          'WHERE metric = ? AND $column >= ? AND $column < ?',
          [metricId, start, end],
        );
        final row = rows.single;
        final n = (row['n'] as num?)?.toInt() ?? 0;
        if (n == 0) {
          batch.delete(
            HealthSchema.daily,
            where: 'metric = ? AND day = ?',
            whereArgs: [metricId, day],
          );
        } else {
          batch.insert(HealthSchema.daily, {
            'metric': metricId,
            'day': day,
            'total': (row['total'] as num?)?.toDouble(),
            'avg': (row['avg'] as num?)?.toDouble(),
            'lo': (row['lo'] as num?)?.toDouble(),
            'hi': (row['hi'] as num?)?.toDouble(),
            'n': n,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        queued++;
      }
    }
    if (queued > 0) await batch.commit(noResult: true);
  }

  /// Fills the denormalised summary columns on sessions from the fact tables.
  ///
  /// A workout's distance, energy and heart rate arrive as separate Health
  /// Connect records, not as fields on the session, so they can only be joined
  /// once both sides are stored. Doing it in SQL keeps the old in-memory
  /// overlap matching - which held every candidate record in a list - out of the
  /// import path.
  ///
  /// Scoped to a window by default so an incremental import does not rewrite
  /// every session it has ever seen.
  Future<void> refreshSessionSummaries({int? from, int? to}) async {
    final db = await _db();
    final points = db.nameTable(HealthSchema.point);
    final intervals = db.nameTable(HealthSchema.interval);
    final sessions = db.nameTable(HealthSchema.session);
    final hr = _metricIds[HealthMetrics.heartRate];
    final speed = _metricIds[HealthMetrics.speed];
    final distance = _metricIds[HealthMetrics.distance];
    final energy = _metricIds[HealthMetrics.activeEnergy];
    final steps = _metricIds[HealthMetrics.steps];
    // An overlap test, not containment: a distance record can start a second
    // before the session it belongs to.
    String overlap(int? metricId, String aggregate) => metricId == null
        ? 'NULL'
        : '(SELECT $aggregate FROM $intervals i WHERE i.metric = $metricId '
              'AND i.t0 < s.t1 AND i.t1 > s.t0)';
    String during(int? metricId, String aggregate) => metricId == null
        ? 'NULL'
        : '(SELECT $aggregate FROM $points p WHERE p.metric = $metricId '
              'AND p.t >= s.t0 AND p.t <= s.t1)';
    final where = <String>['kind = ${HealthSchema.sessionKindExercise}'];
    final args = <Object?>[];
    if (from != null) {
      where.add('t1 >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('t0 < ?');
      args.add(to);
    }
    await db.rawUpdate(
      'UPDATE $sessions AS s SET '
      'distance_km = ${overlap(distance, 'SUM(i.v)')}, '
      'calories = ${overlap(energy, 'SUM(i.v)')}, '
      'steps = ${overlap(steps, 'CAST(SUM(i.v) AS INTEGER)')}, '
      'avg_hr = ${during(hr, 'AVG(p.v)')}, '
      'max_hr = ${during(hr, 'MAX(p.v)')}, '
      'avg_speed = ${during(speed, 'AVG(p.v)')}, '
      'max_speed = ${during(speed, 'MAX(p.v)')} '
      'WHERE ${where.join(' AND ')}',
      args,
    );
  }

  /// Rebuilds every daily rollup from the fact tables. Only needed after a bulk
  /// change that bypassed [writeRecords], such as the backfill or a restore.
  Future<void> rebuildDaily({
    void Function(String status, int count)? onProgress,
  }) async {
    final db = await _db();
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    await db.delete(HealthSchema.daily);
    for (final entry in _metricIds.entries) {
      final spec = HealthMetrics.spec(entry.key);
      if (spec == null) continue;
      final isInterval = spec.shape == HealthMetricShape.interval;
      final table = db.nameTable(
        isInterval ? HealthSchema.interval : HealthSchema.point,
      );
      final column = isInterval ? 't0' : 't';
      // Grouping in SQL by local midnight keeps this one pass per metric
      // instead of one query per day.
      await db.rawInsert(
        'INSERT OR REPLACE INTO ${db.nameTable(HealthSchema.daily)} '
        '(metric, day, total, avg, lo, hi, n) '
        "SELECT metric, CAST(strftime('%s', $column / 1000, 'unixepoch', "
        "'localtime', 'start of day') AS INTEGER) * 1000, "
        'SUM(v), AVG(v), MIN(v), MAX(v), COUNT(*) '
        'FROM $table WHERE metric = ? GROUP BY 2',
        [entry.value],
      );
      onProgress?.call('Rebuilding ${entry.key}...', 0);
    }
    if (kDebugMode) {
      debugLog(
        '[HealthStore] Daily rollups rebuilt in ${stopwatch!.elapsedMilliseconds}ms',
      );
    }
  }

  Future<List<HealthDailyValue>> dailyRange({
    required String metric,
    required int fromDay,
    required int toDay,
  }) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null) return const [];
    final rows = await db.query(
      HealthSchema.daily,
      where: 'metric = ? AND day >= ? AND day <= ?',
      whereArgs: [metricId, fromDay, toDay],
      orderBy: 'day ASC',
    );
    return rows.map(_dailyFromRow).toList();
  }

  Future<Map<String, HealthDailyValue>> dailyForDay(int day) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.daily,
      where: 'day = ?',
      whereArgs: [day],
    );
    final byId = {
      for (final entry in _metricIds.entries) entry.value: entry.key,
    };
    return {
      for (final row in rows)
        if (byId[row['metric'] as int] != null)
          byId[row['metric'] as int]!: _dailyFromRow(row),
    };
  }

  static HealthDailyValue _dailyFromRow(Map<String, Object?> row) =>
      HealthDailyValue(
        day: row['day'] as int,
        total: (row['total'] as num?)?.toDouble(),
        avg: (row['avg'] as num?)?.toDouble(),
        lo: (row['lo'] as num?)?.toDouble(),
        hi: (row['hi'] as num?)?.toDouble(),
        n: (row['n'] as num?)?.toInt() ?? 0,
      );

  /// All-time sum of a total metric, straight off the rollups.
  Future<double> allTimeTotal(String metric) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null) return 0;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS v '
      'FROM ${db.nameTable(HealthSchema.daily)} WHERE metric = ?',
      [metricId],
    );
    return (rows.single['v'] as num?)?.toDouble() ?? 0;
  }

  /// Newest measurement of a metric. A primary key seek, so it stays fast
  /// regardless of how many samples the metric has.
  Future<HealthPoint?> latestPoint(String metric) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null) return null;
    final rows = await db.query(
      HealthSchema.point,
      columns: ['t', 'v', 'v2', 'app'],
      where: 'metric = ?',
      whereArgs: [metricId],
      orderBy: 't DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _pointFromRow(rows.single);
  }

  /// Dense samples inside a window - the workout drilldown. Bounded by the
  /// primary key, never a scan.
  Future<List<HealthPoint>> pointsInRange({
    required String metric,
    required int from,
    required int to,
    String? package,
  }) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null) return const [];
    final where = StringBuffer('metric = ? AND t >= ? AND t <= ?');
    final args = <Object?>[metricId, from, to];
    if (package != null) {
      final appId = _appIds[package];
      if (appId != null) {
        where.write(' AND app = ?');
        args.add(appId);
      }
    }
    final rows = await db.query(
      HealthSchema.point,
      columns: ['t', 'v', 'v2', 'app'],
      where: where.toString(),
      whereArgs: args,
      orderBy: 't ASC',
    );
    return rows.map(_pointFromRow).toList();
  }

  Future<List<HealthInterval>> intervalsInRange({
    required String metric,
    required int from,
    required int to,
  }) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null) return const [];
    final rows = await db.query(
      HealthSchema.interval,
      columns: ['t0', 't1', 'v', 'app'],
      where: 'metric = ? AND t0 >= ? AND t0 < ?',
      whereArgs: [metricId, from, to],
      orderBy: 't0 ASC',
    );
    return rows.map(_intervalFromRow).toList();
  }

  Future<List<HealthInterval>> intervalPage({
    required String metric,
    required int offset,
    required int limit,
  }) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null || limit <= 0) return const [];
    final rows = await db.query(
      HealthSchema.interval,
      columns: ['t0', 't1', 'v', 'app'],
      where: 'metric = ?',
      whereArgs: [metricId],
      orderBy: 't0 DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_intervalFromRow).toList();
  }

  Future<List<HealthPoint>> pointPage({
    required String metric,
    required int offset,
    required int limit,
  }) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null || limit <= 0) return const [];
    final rows = await db.query(
      HealthSchema.point,
      columns: ['t', 'v', 'v2', 'app'],
      where: 'metric = ?',
      whereArgs: [metricId],
      orderBy: 't DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_pointFromRow).toList();
  }

  /// Row count for a metric, taken from the rollups rather than the dense table:
  /// `health_daily.n` already sums to it, and there are a few hundred of those
  /// rows against potentially millions of measurements.
  Future<int> metricCount(String metric) async {
    final db = await _db();
    final metricId = _metricIds[metric];
    if (metricId == null) return 0;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(n), 0) AS n '
      'FROM ${db.nameTable(HealthSchema.daily)} WHERE metric = ?',
      [metricId],
    );
    return (rows.single['n'] as num?)?.toInt() ?? 0;
  }

  HealthInterval _intervalFromRow(Map<String, Object?> row) => HealthInterval(
    row['t0'] as int,
    row['t1'] as int,
    (row['v'] as num).toDouble(),
    _appPackages[row['app'] as int? ?? -1],
  );

  HealthPoint _pointFromRow(Map<String, Object?> row) => HealthPoint(
    row['t'] as int,
    (row['v'] as num).toDouble(),
    (row['v2'] as num?)?.toDouble(),
    _appPackages[row['app'] as int? ?? -1],
  );

  Future<List<HealthSession>> sessions({
    int? kind,
    int? from,
    int? to,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _db();
    final where = <String>[];
    final args = <Object?>[];
    if (kind != null) {
      where.add('kind = ?');
      args.add(kind);
    }
    if (from != null) {
      where.add('t1 >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('t0 < ?');
      args.add(to);
    }
    final rows = await db.query(
      HealthSchema.session,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 't0 DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_sessionFromRow).toList();
  }

  Future<List<HealthSessionPart>> sessionParts(int sessionId) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.sessionPart,
      where: 'session = ?',
      whereArgs: [sessionId],
      orderBy: 'seq ASC',
    );
    return rows
        .map(
          (row) => HealthSessionPart(
            kind: row['kind'] as int,
            part: _textValues[row['part'] as int? ?? -1],
            t0: row['t0'] as int?,
            t1: row['t1'] as int?,
            v: (row['v'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  HealthSession _sessionFromRow(Map<String, Object?> row) => HealthSession(
    id: row['id'] as int,
    kind: row['kind'] as int,
    activity: _textValues[row['activity'] as int? ?? -1],
    title: _textValues[row['title'] as int? ?? -1],
    notes: row['notes'] as String?,
    t0: row['t0'] as int,
    t1: row['t1'] as int,
    package: _appPackages[row['app'] as int? ?? -1],
    origin: row['origin'] as String,
    clientId: row['client_id'] as String?,
    distanceKm: (row['distance_km'] as num?)?.toDouble(),
    calories: (row['calories'] as num?)?.toDouble(),
    steps: (row['steps'] as num?)?.toInt(),
    avgHr: (row['avg_hr'] as num?)?.toDouble(),
    maxHr: (row['max_hr'] as num?)?.toDouble(),
    avgSpeed: (row['avg_speed'] as num?)?.toDouble(),
    maxSpeed: (row['max_speed'] as num?)?.toDouble(),
    asleepMin: (row['asleep_min'] as num?)?.toInt(),
  );

  /// Aggregate workout figures across all sessions, off the denormalised
  /// summary columns rather than by parsing anything.
  Future<Map<String, num>> workoutSummary() async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(distance_km), 0) AS distance, '
      'COALESCE(SUM(calories), 0) AS calories, '
      'COALESCE(SUM((t1 - t0) / 1000), 0) AS duration, '
      'COUNT(*) AS workouts '
      'FROM ${db.nameTable(HealthSchema.session)} WHERE kind = ?',
      [HealthSchema.sessionKindExercise],
    );
    final row = rows.single;
    return {
      'distance': (row['distance'] as num?) ?? 0,
      'calories': (row['calories'] as num?) ?? 0,
      'duration': (row['duration'] as num?) ?? 0,
      'workouts': (row['workouts'] as num?) ?? 0,
    };
  }

  Future<void> deleteSessionsByOrigin(Iterable<String> origins) async {
    if (origins.isEmpty) return;
    final db = await _db();
    final placeholders = List.filled(origins.length, '?').join(', ');
    await db.transaction((txn) async {
      final sessions = txn.nameTable(HealthSchema.session);
      await txn.rawDelete(
        'DELETE FROM ${txn.nameTable(HealthSchema.sessionPart)} '
        'WHERE session IN (SELECT id FROM $sessions WHERE origin IN ($placeholders))',
        origins.toList(),
      );
      await txn.rawDelete(
        'DELETE FROM $sessions WHERE origin IN ($placeholders)',
        origins.toList(),
      );
    });
  }

  /// Removes interval rows for deleted Health Connect records, then repairs the
  /// daily rollups for the days they covered - a deleted steps record has to
  /// leave the day's total.
  Future<void> deleteIntervalsByOrigin(Iterable<String> origins) async {
    if (origins.isEmpty) return;
    final db = await _db();
    final ids = origins.toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final affected = await db.query(
      HealthSchema.interval,
      columns: ['metric', 't0'],
      where: 'origin IN ($placeholders)',
      whereArgs: ids,
    );
    if (affected.isEmpty) return;
    final touched = <int, Set<int>>{};
    for (final row in affected) {
      (touched[row['metric'] as int] ??= <int>{}).add(dayKey(row['t0'] as int));
    }
    await db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM ${txn.nameTable(HealthSchema.interval)} '
        'WHERE origin IN ($placeholders)',
        ids,
      );
      await _refreshDaily(txn, touched);
    });
  }

  /// Drops every row a writer contributed, for when the user deselects it. The
  /// rollups are rebuilt because a removed writer changes daily aggregates.
  Future<void> deleteApp(String package) async {
    final db = await _db();
    final appId = _appIds[package];
    if (appId == null) return;
    await db.transaction((txn) async {
      final sessions = txn.nameTable(HealthSchema.session);
      await txn.rawDelete(
        'DELETE FROM ${txn.nameTable(HealthSchema.sessionPart)} '
        'WHERE session IN (SELECT id FROM $sessions WHERE app = ?)',
        [appId],
      );
      await txn.delete(
        HealthSchema.session,
        where: 'app = ?',
        whereArgs: [appId],
      );
      await txn.delete(
        HealthSchema.point,
        where: 'app = ?',
        whereArgs: [appId],
      );
      await txn.delete(
        HealthSchema.interval,
        where: 'app = ?',
        whereArgs: [appId],
      );
    });
    await rebuildDaily();
  }

  Future<void> clearImportedData() async {
    final db = await _db();
    await db.transaction((txn) async {
      for (final table in HealthSchema.dataTables) {
        await txn.delete(table);
      }
      await txn.update(HealthSchema.type, {
        'history_done': 0,
        'range_start': null,
        'range_end': null,
        'n': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  // --- type and source selection -------------------------------------------

  Future<List<HealthTypeState>> types() async {
    final db = await _db();
    final rows = await db.query(HealthSchema.type, orderBy: 'type ASC');
    return rows
        .map(
          (row) => HealthTypeState(
            type: row['type'] as String,
            enabled: (row['enabled'] as int) == 1,
            historyDone: (row['history_done'] as int) == 1,
            count: (row['n'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<Set<String>> enabledTypes() async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.type,
      columns: ['type'],
      where: 'enabled = 1',
    );
    return rows.map((row) => row['type'] as String).toSet();
  }

  Future<void> setTypeEnabled(String type, bool enabled) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(HealthSchema.type, {
      'type': type,
      'enabled': enabled ? 1 : 0,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update(
      HealthSchema.type,
      {'enabled': enabled ? 1 : 0, 'updated_at': now},
      where: 'type = ?',
      whereArgs: [type],
    );
  }

  /// Records a type as seen, without disturbing an existing selection.
  Future<void> registerType(String type, {bool defaultEnabled = false}) async {
    final db = await _db();
    await db.insert(HealthSchema.type, {
      'type': type,
      'enabled': defaultEnabled ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> markTypeProgress({
    required String type,
    required int count,
    required bool historyDone,
    int? rangeStart,
    int? rangeEnd,
  }) async {
    final db = await _db();
    await db.update(
      HealthSchema.type,
      {
        'n': count,
        'history_done': historyDone ? 1 : 0,
        'range_start': rangeStart,
        'range_end': rangeEnd,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'type = ?',
      whereArgs: [type],
    );
  }

  Future<Map<String, Object?>?> typeRow(String type) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.type,
      where: 'type = ?',
      whereArgs: [type],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  /// Upserts a discovered writer for a type. An already-known pair keeps its
  /// enabled flag - discovery must never silently re-enable a source the user
  /// turned off.
  Future<void> recordDiscoveredApp({
    required String type,
    required String package,
    required int count,
    int? lastSeen,
  }) async {
    final db = await _db();
    final appId = await _appId(db, package);
    await db.insert(HealthSchema.typeApp, {
      'type': type,
      'app': appId,
      'enabled': 1,
      'n': count,
      'last_t': lastSeen,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update(
      HealthSchema.typeApp,
      {'n': count, 'last_t': lastSeen},
      where: 'type = ? AND app = ?',
      whereArgs: [type, appId],
    );
  }

  Future<List<HealthDiscoveredApp>> discoveredApps(String type) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.typeApp,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'n DESC',
    );
    return rows
        .map(
          (row) => HealthDiscoveredApp(
            appId: row['app'] as int,
            package: _appPackages[row['app'] as int] ?? '?',
            enabled: (row['enabled'] as int) == 1,
            count: (row['n'] as num?)?.toInt() ?? 0,
            lastSeen: row['last_t'] as int?,
          ),
        )
        .toList();
  }

  /// Packages the user pulls for a type. Empty means no restriction, which is
  /// also what a type looks like before discovery has run.
  /// Packages to pass as `dataOrigins` when reading [type], or empty for no
  /// restriction.
  ///
  /// This filter may only ever **exclude**. Discovery is a bounded probe - a
  /// recent window, a few pages per type - so it cannot be treated as a complete
  /// list of writers. Using its output as an allowlist silently dropped every
  /// writer the probe happened not to see, which is how a full import ended up
  /// containing nothing but the one app that had written most recently.
  ///
  /// So a restriction is applied only when the user has actually switched
  /// something off for this type. With everything enabled - the default, and the
  /// state right after discovery - no filter is sent and undiscovered writers
  /// still come in.
  Future<List<String>> dataOriginFilter(String type) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.typeApp,
      columns: ['app', 'enabled'],
      where: 'type = ?',
      whereArgs: [type],
    );
    if (rows.isEmpty) return const [];
    final hasExclusion = rows.any((row) => (row['enabled'] as int) == 0);
    if (!hasExclusion) return const [];
    return rows
        .where((row) => (row['enabled'] as int) == 1)
        .map((row) => _appPackages[row['app'] as int])
        .whereType<String>()
        .toList();
  }

  Future<void> setAppEnabled({
    required String type,
    required String package,
    required bool enabled,
  }) async {
    final db = await _db();
    final appId = _appIds[package];
    if (appId == null) return;
    await db.update(
      HealthSchema.typeApp,
      {'enabled': enabled ? 1 : 0},
      where: 'type = ? AND app = ?',
      whereArgs: [type, appId],
    );
  }

  // --- backup ---------------------------------------------------------------

  static const _backupMarkerTable = 'health_backup_marker';

  /// Copies this tool's tables into a standalone database file. The work happens
  /// inside SQLite, so nothing is materialised as Dart objects and the cost is
  /// bounded by disk rather than by row count.
  Future<String> exportBackup({
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await _db();
    final path = await TempFileManager.createFile('health_dashboard_backup.db');
    final file = File(path);
    // ATTACH wants to create the file itself; TempFileManager may already have
    // made an empty placeholder.
    if (await file.exists()) await file.delete();
    final total = HealthSchema.backupTables.length;
    onProgress?.call(0, total);
    await db.execute('ATTACH DATABASE ? AS backup', [path]);
    try {
      await db.execute(
        'CREATE TABLE backup.$_backupMarkerTable '
        '(tool_id TEXT NOT NULL, schema_version INTEGER NOT NULL, '
        'exported_at INTEGER NOT NULL)',
      );
      await db
          .execute('INSERT INTO backup.$_backupMarkerTable VALUES (?, ?, ?)', [
            HealthDashboardTool.config.id,
            HealthSchema.version,
            DateTime.now().millisecondsSinceEpoch,
          ]);
      var processed = 0;
      for (final table in HealthSchema.backupTables) {
        await db.execute(
          'CREATE TABLE backup.$table AS SELECT * FROM ${db.nameTable(table)}',
        );
        onProgress?.call(++processed, total);
      }
    } finally {
      await db.execute('DETACH DATABASE backup');
    }
    return path;
  }

  /// Merges a backup back in. Rows match on their primary key, so re-importing
  /// the same file is idempotent. The dimension tables come along, otherwise the
  /// interned integers in the restored facts would resolve to nothing.
  Future<int> importBackup(
    String path, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final probe = await openDatabase(path, readOnly: true);
    try {
      final marker = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [_backupMarkerTable],
      );
      if (marker.isEmpty) {
        throw const FormatException('Not a Health Dashboard backup.');
      }
    } finally {
      await probe.close();
    }
    final db = await _db();
    final total = HealthSchema.backupTables.length;
    var processed = 0;
    var imported = 0;
    onProgress?.call(0, total);
    await db.execute('ATTACH DATABASE ? AS backup', [path]);
    try {
      for (final table in HealthSchema.backupTables) {
        final present = await db.rawQuery(
          "SELECT name FROM backup.sqlite_master WHERE type = 'table' AND name = ?",
          [table],
        );
        if (present.isNotEmpty) {
          imported += await db.rawUpdate(
            'INSERT OR REPLACE INTO ${db.nameTable(table)} '
            'SELECT * FROM backup.$table',
          );
        }
        onProgress?.call(++processed, total);
      }
    } finally {
      await db.execute('DETACH DATABASE backup');
    }
    // The restored file brings its own dimension rows, so the interning caches
    // are stale and the rollups must be rebuilt from the merged facts.
    reset();
    await _db();
    await rebuildDaily();
    return imported;
  }

  /// Flat JSON of the typed store, for inspecting it outside the app.
  Future<String> exportJson() async {
    final db = await _db();
    final export = <String, dynamic>{
      'schemaVersion': HealthSchema.version,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    for (final table in HealthSchema.backupTables) {
      export[table] = await db.query(table);
    }
    final path = await TempFileManager.createFile(
      'health_dashboard_export_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await File(
      path,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(export));
    return path;
  }

  Future<Map<String, int>> rowCounts() async {
    final db = await _db();
    final counts = <String, int>{};
    for (final table in [
      HealthSchema.point,
      HealthSchema.interval,
      HealthSchema.session,
      HealthSchema.daily,
    ]) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM ${db.nameTable(table)}',
      );
      counts[table] = (rows.single['n'] as num?)?.toInt() ?? 0;
    }
    return counts;
  }
}

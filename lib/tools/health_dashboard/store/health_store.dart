import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';
import 'health_chunk_codec.dart';
import 'health_metric_catalog.dart';
import 'health_models.dart';
import 'health_rows.dart';
import 'health_schema.dart';

/// Typed store for the health dashboard. Owns the schema in [HealthSchema], the
/// dimension interning, the daily rollups and every read the UI performs.
class HealthStore {
  HealthStore._();

  static final HealthStore instance = HealthStore._();

  /// How much two sessions have to overlap before they count as one activity
  /// two writers each recorded. Measured against the **longer** of the two, so a
  /// short walk logged inside a long run is not swallowed by it - a ratio taken
  /// against the shorter side would read 1.0 there and collapse them.
  static const double _mirrorOverlapRatio = 0.7;

  ToolDatabase? _database;
  Future<ToolDatabase>? _opening;

  final Map<String, int> _metricIds = {};
  final Map<String, int> _appIds = {};
  final Map<String, int> _textIds = {};
  final Map<int, String> _appPackages = {};
  final Map<int, String> _textValues = {};

  /// Writers the user switched off globally. Held in memory because every dense
  /// read has to exclude them and a join to `health_app` per query would cost
  /// more than inlining a handful of integers.
  final Set<int> _disabledApps = {};

  /// Writer priority, lower wins. Decides which single app a day's rollup is
  /// computed from, and which side of an exact session mirror is kept.
  final Map<int, int> _appPrio = {};

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
        if (oldVersion < 1) {
          await HealthSchema.create(txn);
          return;
        }
        if (oldVersion < 2) await HealthSchema.migrateToV2(txn);
        if (oldVersion < 3) await HealthSchema.migrateToV3(txn);
        if (oldVersion < 4) await HealthSchema.migrateToV4(txn);
        if (oldVersion < 5) await HealthSchema.migrateToV5(txn);
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
      for (final table in [
        ..._preTypedTables,
        ...HealthSchema.backupTables,
        HealthSchema.chunk,
      ]) {
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
    _disabledApps.clear();
    _appPrio.clear();
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
      _appPrio[id] = (row['prio'] as num?)?.toInt() ?? HealthSchema.defaultPrio;
      if ((row['enabled'] as int? ?? 1) == 0) _disabledApps.add(id);
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
    _appPrio[id] = HealthSchema.defaultPrio;
    return id;
  }

  /// `AND app NOT IN (...)` for a query that must skip globally disabled
  /// writers, or an empty string when nothing is disabled. Disabling keeps the
  /// rows - it only stops them being read and aggregated - so every read has to
  /// carry this.
  String _excludeDisabled([String column = 'app']) => _disabledApps.isEmpty
      ? ''
      : ' AND $column NOT IN (${_disabledApps.join(', ')})';

  int _prioOf(int appId) => _appPrio[appId] ?? HealthSchema.defaultPrio;

  /// Priority as an inline SQL expression rather than a join to `health_app`.
  /// There are a handful of writers, and this keeps the rollup queries reading
  /// nothing but the dense table's own index.
  String _prioOrderSql([String column = 'app']) {
    if (_appPrio.isEmpty) return '${HealthSchema.defaultPrio}';
    final whens = _appPrio.entries
        .map((entry) => 'WHEN ${entry.key} THEN ${entry.value}')
        .join(' ');
    return 'CASE $column $whens ELSE ${HealthSchema.defaultPrio} END';
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
  ///
  /// Returns the rows that were actually stored, not the rows offered: a
  /// re-read hands the same measurements back and they collapse on insert, so
  /// counting what arrived would report changes on a page that changed nothing.
  Future<int> writeRecords(Iterable<HealthMappedRecord> records) async {
    final db = await _db();
    var written = 0;
    // (metricId, dayKey) pairs, so a page spanning three days recomputes three
    // days rather than the whole metric.
    final touched = <int, Set<int>>{};
    // (chunkDay, appId) pairs that actually gained rows.
    final dirty = <(int, int)>{};
    await db.transaction((txn) async {
      // Batched per chunk rather than per page, so the row counter below can
      // attribute what it inserted. A page is one writer over a few days, so
      // this is a handful of commits, not one per row.
      final batches = <(int, int), ToolBatch>{};
      for (final record in records) {
        if (record.isEmpty) continue;
        final appId = await _appId(txn, record.package);
        for (final row in record.points) {
          final metricId = await _metricId(txn, row.metric);
          final key = (HealthSchema.chunkDay(row.t), appId);
          (batches[key] ??= txn.batch()).insert(HealthSchema.point, {
            'metric': metricId,
            't': row.t,
            'v': row.v,
            'v2': row.v2,
            'app': appId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          (touched[metricId] ??= <int>{}).add(dayKey(row.t));
        }
        for (final row in record.intervals) {
          final metricId = await _metricId(txn, row.metric);
          final key = (HealthSchema.chunkDay(row.t0), appId);
          (batches[key] ??= txn.batch()).insert(HealthSchema.interval, {
            'metric': metricId,
            't0': row.t0,
            't1': row.t1,
            'v': row.v,
            'app': appId,
            'origin': row.origin,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          (touched[metricId] ??= <int>{}).add(dayKey(row.t0));
        }
      }
      for (final record in records) {
        final nutrition = record.nutrition;
        if (nutrition == null) continue;
        final appId = await _appId(txn, record.package);
        final changed = await _writeNutrition(txn, appId, nutrition);
        if (changed) {
          dirty.add((HealthSchema.chunkDay(nutrition.t0), appId));
          written++;
        }
      }
      for (final entry in batches.entries) {
        final before = await _totalChanges(txn);
        await entry.value.commit(noResult: true);
        final inserted = await _totalChanges(txn) - before;
        if (inserted > 0) dirty.add(entry.key);
        written += inserted;
      }
      // Sessions need their generated id, so they cannot ride the batch.
      for (final record in records) {
        final session = record.session;
        if (session == null) continue;
        final appId = await _appId(txn, record.package);
        final changed = await _writeSession(
          txn,
          appId,
          record.package,
          session,
        );
        if (changed) {
          dirty.add((HealthSchema.chunkDay(session.t0), appId));
          written++;
        }
      }
      await _markChunks(txn, dirty);
      await _refreshDaily(txn, touched);
    });
    return written;
  }

  /// Rows this connection has written since it opened. Read either side of a
  /// commit it gives the number of rows an `INSERT OR IGNORE` batch actually
  /// inserted, which sqflite's own result cannot: a `WITHOUT ROWID` table leaves
  /// `last_insert_rowid()` untouched, so an ignored insert is indistinguishable
  /// from a real one. Safe inside a transaction, where nothing else writes.
  Future<int> _totalChanges(ToolDatabaseExecutor db) async {
    final rows = await db.rawQuery('SELECT total_changes() AS n');
    return (rows.single['n'] as num?)?.toInt() ?? 0;
  }

  /// Marks chunks as holding rows the backend has not seen. Only called for
  /// pairs that actually gained content: bumping on every import would make each
  /// run re-upload a full day, and the other device pull it straight back.
  Future<void> _markChunks(
    ToolDatabaseExecutor db,
    Set<(int, int)> chunks,
  ) async {
    if (chunks.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final (day, app) in chunks) {
      batch.insert(HealthSchema.chunk, {
        'day': day,
        'app': app,
        'updated_at': now,
        'dirty': 1,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Returns whether the stored data changed, which is what decides if the
  /// session's chunk owes the backend anything.
  Future<bool> _writeSession(
    ToolDatabaseExecutor db,
    int appId,
    String package,
    HealthSessionRow row,
  ) async {
    final dedupeKey = HealthSchema.dedupeKey(
      kind: row.kind,
      t0: row.t0,
      t1: row.t1,
      package: package,
      clientId: row.clientId,
    );
    // Identity first, and outside the time window below: a writer that shifted
    // a workout's bounds still reports the same client record. Origin is the
    // fallback rather than the rule - measured across a phone and a tablet it
    // agrees for 624/626 exercise sessions but only 152/167 sleep ones, so it
    // catches a row an edited range moved out of reach of the key while being
    // too unreliable to identify a session on its own.
    var identical = await db.query(
      HealthSchema.session,
      where: 'dedupe_key = ?',
      whereArgs: [dedupeKey],
      limit: 1,
    );
    final origin = row.origin;
    if (identical.isEmpty && origin != null && origin.isNotEmpty) {
      identical = await db.query(
        HealthSchema.session,
        where: 'origin = ?',
        whereArgs: [origin],
        limit: 1,
      );
    }
    // A session another app already stored for the same activity is a mirror.
    // Two writers rarely agree on where an activity starts and ends - a
    // republisher rewrites a watch's workout to the millisecond, but a treadmill
    // and a watch timing the same run differ at both ends - so the match is an
    // overlap, not an equality. Priority decides which side survives, which is
    // what makes promoting a writer flip an already-imported mirror on the next
    // import; ties keep the first writer. Same-app sessions only collapse on an
    // exact range: an app that logs two overlapping activities means it.
    final span = max(1, row.t1 - row.t0);
    Map<String, Object?>? existing = identical.isEmpty ? null : identical.first;
    Map<String, Object?>? mirror;
    if (existing == null) {
      final candidates = await db.query(
        HealthSchema.session,
        columns: ['id', 'app', 't0', 't1'],
        // Anything clearing the ratio has to start within one span of this row,
        // which bounds the scan instead of walking every session ever stored.
        where: 'kind = ? AND t0 >= ? AND t0 < ? AND t1 > ?',
        whereArgs: [row.kind, row.t0 - span, row.t1, row.t0],
      );
      var bestRatio = 0.0;
      for (final candidate in candidates) {
        final t0 = candidate['t0'] as int;
        final t1 = candidate['t1'] as int;
        final exact = t0 == row.t0 && t1 == row.t1;
        if (candidate['app'] as int == appId && !exact) continue;
        final overlap = min(t1, row.t1) - max(t0, row.t0);
        final ratio = overlap / max(span, max(1, t1 - t0));
        if (ratio >= _mirrorOverlapRatio && ratio > bestRatio) {
          bestRatio = ratio;
          mirror = candidate;
        }
      }
    }
    if (existing == null && mirror != null) {
      if (_prioOf(appId) >= _prioOf(mirror['app'] as int)) return false;
      // The better-ranked writer takes the slot: the mirror's parts go with it,
      // since the row they hang off is replaced.
      final mirrorId = mirror['id'] as int;
      await db.delete(
        HealthSchema.sessionPart,
        where: 'session = ?',
        whereArgs: [mirrorId],
      );
      await db.delete(
        HealthSchema.session,
        where: 'id = ?',
        whereArgs: [mirrorId],
      );
    }
    final values = {
      'kind': row.kind,
      'activity': await _textId(db, row.activity),
      'title': await _textId(db, row.title),
      'notes': row.notes,
      't0': row.t0,
      't1': row.t1,
      'app': appId,
      'origin': row.origin,
      'dedupe_key': dedupeKey,
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
    final stored = existing;
    if (stored != null) {
      // A re-import that carries the same row must leave the store alone, or
      // every run would mark the chunk dirty and re-upload the day. Parts are
      // left alone too: they come out of the same record, so a summary that did
      // not move means nothing under it moved either.
      if (values.entries.every((e) => stored[e.key] == e.value)) return false;
      sessionId = stored['id'] as int;
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
    if (row.parts.isEmpty) return true;
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
    return true;
  }

  Future<bool> _writeNutrition(
    ToolDatabaseExecutor db,
    int appId,
    HealthNutritionRow row,
  ) async {
    final key = row.clientId?.isNotEmpty == true
        ? 'c:${row.clientId}'
        : 'k:$appId|${row.t0}|${row.t1}|${row.foodName}|${row.energyKcal}';
    final values = {
      't0': row.t0,
      't1': row.t1,
      'app': appId,
      'origin': row.origin,
      'client_id': row.clientId,
      'food_name': row.foodName,
      'meal_type': row.mealType,
      'energy_kcal': row.energyKcal,
      'protein_g': row.proteinG,
      'carbohydrate_g': row.carbohydrateG,
      'fat_g': row.fatG,
      'dedupe_key': key,
    };
    final existing = await db.query(
      HealthSchema.nutrition,
      where: 'dedupe_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if (values.entries.every(
        (entry) => existing.single[entry.key] == entry.value,
      )) {
        return false;
      }
      await db.update(
        HealthSchema.nutrition,
        values,
        where: 'id = ?',
        whereArgs: [existing.single['id']],
      );
      return true;
    }
    await db.insert(HealthSchema.nutrition, values);
    return true;
  }

  /// A day's rollup is computed from **one** writer, never from all of them at
  /// once.
  ///
  /// Summing across writers was the actual cause of inflated step and distance
  /// totals: a republisher re-buckets the same walk into different intervals, so
  /// the rows are not byte-identical, the primary key cannot collapse them, and
  /// both landed in the day's total. Averages had the same problem in a quieter
  /// way - `n`, `lo` and `hi` mixed two writers' streams.
  ///
  /// The winner is the enabled writer with the best `prio`, then the one with
  /// the most rows that day, then the lowest id so the choice is deterministic.
  /// Picking per day rather than globally is what keeps a republisher useful:
  /// on a day no other writer covered, it wins by default and the data still
  /// shows up.
  static const _dailyWinnerColumns =
      'SUM(v) AS total, AVG(v) AS avg, MIN(v) AS lo, MAX(v) AS hi, '
      'COUNT(*) AS n';

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
    final prioCase = _prioOrderSql();
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
          'SELECT $_dailyWinnerColumns FROM $table '
          'WHERE metric = ? AND $column >= ? AND $column < ?'
          '${_excludeDisabled()} '
          'GROUP BY app ORDER BY $prioCase ASC, n DESC, app ASC LIMIT 1',
          [metricId, start, end],
        );
        final row = rows.isEmpty ? const <String, Object?>{} : rows.single;
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
              'AND i.app = s.app AND i.t0 < s.t1 AND i.t1 > s.t0)';
    String during(int? metricId, String aggregate) => metricId == null
        ? 'NULL'
        : '(SELECT $aggregate FROM $points p WHERE p.metric = $metricId '
              'AND p.app = s.app AND p.t >= s.t0 AND p.t <= s.t1)';
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
  ///
  /// [sessions] also refreshes the denormalised session summaries, which is the
  /// expensive half on a large store. A summary is computed from its own
  /// writer's rows, so a change that only moved writers around - a priority
  /// reorder, a global switch - cannot alter one and skips the pass.
  Future<void> rebuildDaily({
    bool sessions = true,
    void Function(String status, int count)? onProgress,
  }) async {
    if (sessions) await refreshSessionSummaries();
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
      // One pass per metric, grouped by local midnight *and* writer. Picking the
      // day's winner needs both aggregates and the writer, which no single
      // GROUP BY can express - so the reduction happens here and the winner is
      // chosen in Dart. Rows are bounded by days x writers, not by measurements.
      //
      // The trailing 'utc' is what makes the key match [dayKey]: without it
      // strftime returns the local wall clock read as if it were UTC, which is
      // only the same instant where the offset is zero. Every reader looks the
      // day up by [dayKey], so a shifted key is a rollup nothing ever finds.
      final grouped = await db.rawQuery(
        "SELECT CAST(strftime('%s', datetime($column / 1000, 'unixepoch', "
        "'localtime', 'start of day'), 'utc') AS INTEGER) * 1000 AS day, "
        'app, $_dailyWinnerColumns '
        'FROM $table WHERE metric = ?${_excludeDisabled()} '
        'GROUP BY day, app',
        [entry.value],
      );
      final winners = <int, Map<String, Object?>>{};
      for (final row in grouped) {
        final day = (row['day'] as num).toInt();
        final best = winners[day];
        if (best == null || _beatsDailyWinner(row, best)) winners[day] = row;
      }
      final batch = db.batch();
      for (final win in winners.entries) {
        batch.insert(HealthSchema.daily, {
          'metric': entry.value,
          'day': win.key,
          'total': (win.value['total'] as num?)?.toDouble(),
          'avg': (win.value['avg'] as num?)?.toDouble(),
          'lo': (win.value['lo'] as num?)?.toDouble(),
          'hi': (win.value['hi'] as num?)?.toDouble(),
          'n': (win.value['n'] as num?)?.toInt() ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (winners.isNotEmpty) await batch.commit(noResult: true);
      onProgress?.call('Rebuilding ${entry.key}...', 0);
    }
    if (kDebugMode) {
      debugLog(
        '[HealthStore] Daily rollups rebuilt in ${stopwatch!.elapsedMilliseconds}ms',
      );
    }
  }

  /// Same ordering as the SQL winner pick in [_refreshDaily]: priority, then
  /// row count, then app id.
  bool _beatsDailyWinner(
    Map<String, Object?> candidate,
    Map<String, Object?> current,
  ) {
    final candidateApp = (candidate['app'] as num).toInt();
    final currentApp = (current['app'] as num).toInt();
    final byPrio = _prioOf(candidateApp).compareTo(_prioOf(currentApp));
    if (byPrio != 0) return byPrio < 0;
    final byCount = ((current['n'] as num?)?.toInt() ?? 0).compareTo(
      (candidate['n'] as num?)?.toInt() ?? 0,
    );
    if (byCount != 0) return byCount < 0;
    return candidateApp < currentApp;
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
      where: 'metric = ?${_excludeDisabled()}',
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
    final where = StringBuffer('metric = ? AND t >= ? AND t <= ?')
      ..write(_excludeDisabled());
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
      where: 'metric = ? AND t0 >= ? AND t0 < ?${_excludeDisabled()}',
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
      where: 'metric = ?${_excludeDisabled()}',
      whereArgs: [metricId],
      orderBy: 't0 DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_intervalFromRow).toList();
  }

  Future<List<HealthNutrition>> nutrition({
    int? from,
    int? to,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _db();
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('t0 >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('t0 < ?');
      args.add(to);
    }
    if (_disabledApps.isNotEmpty) {
      where.add('app NOT IN (${_disabledApps.join(', ')})');
    }
    final rows = await db.query(
      HealthSchema.nutrition,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 't0 DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_nutritionFromRow).toList();
  }

  Future<Map<String, double>> nutritionTotals({int? from, int? to}) async {
    final db = await _db();
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('t0 >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('t0 < ?');
      args.add(to);
    }
    if (_disabledApps.isNotEmpty) {
      where.add('app NOT IN (${_disabledApps.join(', ')})');
    }
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(energy_kcal), 0) AS energy, '
      'COALESCE(SUM(protein_g), 0) AS protein, '
      'COALESCE(SUM(carbohydrate_g), 0) AS carbohydrate, '
      'COALESCE(SUM(fat_g), 0) AS fat FROM ${db.nameTable(HealthSchema.nutrition)}'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      args,
    );
    final row = rows.single;
    return {
      'energy': (row['energy'] as num).toDouble(),
      'protein': (row['protein'] as num).toDouble(),
      'carbohydrate': (row['carbohydrate'] as num).toDouble(),
      'fat': (row['fat'] as num).toDouble(),
    };
  }

  HealthNutrition _nutritionFromRow(Map<String, Object?> row) =>
      HealthNutrition(
        id: row['id'] as int,
        t0: row['t0'] as int,
        t1: row['t1'] as int,
        package: _appPackages[row['app'] as int? ?? -1],
        origin: row['origin'] as String?,
        clientId: row['client_id'] as String?,
        foodName: row['food_name'] as String?,
        mealType: row['meal_type'] as String?,
        energyKcal: (row['energy_kcal'] as num?)?.toDouble(),
        proteinG: (row['protein_g'] as num?)?.toDouble(),
        carbohydrateG: (row['carbohydrate_g'] as num?)?.toDouble(),
        fatG: (row['fat_g'] as num?)?.toDouble(),
      );

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
      where: 'metric = ?${_excludeDisabled()}',
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
    if (_disabledApps.isNotEmpty) {
      where.add('app NOT IN (${_disabledApps.join(', ')})');
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
    origin: row['origin'] as String?,
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
  Future<Map<String, num>> workoutSummary({int? from, int? to}) async {
    final db = await _db();
    final where = <String>['kind = ?${_excludeDisabled()}'];
    final args = <Object?>[HealthSchema.sessionKindExercise];
    if (from != null) {
      where.add('t1 >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('t0 < ?');
      args.add(to);
    }
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(distance_km), 0) AS distance, '
      'COALESCE(SUM(calories), 0) AS calories, '
      'COALESCE(SUM((t1 - t0) / 1000), 0) AS duration, '
      'COUNT(*) AS workouts '
      'FROM ${db.nameTable(HealthSchema.session)} '
      'WHERE ${where.join(' AND ')}',
      args,
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

  Future<void> deleteNutritionByOrigin(Iterable<String> origins) async {
    if (origins.isEmpty) return;
    final db = await _db();
    final ids = origins.toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      HealthSchema.nutrition,
      where: 'origin IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Drops every row a writer contributed. This is the explicit "reclaim the
  /// space" action, not what switching a writer off does - that keeps the rows.
  ///
  /// Deleting rows alone does not shrink the database file: SQLite frees the
  /// pages and reuses them for later inserts. [vacuum] rewrites the file so the
  /// space is actually returned to the filesystem, which is the whole point of
  /// deleting a writer with a million heart-rate rows.
  ///
  /// The affected types lose their `history_done` flag so a later import can
  /// read the writer's history again if the user changes their mind. Without
  /// that the importer skips a finished type and the years never come back.
  ///
  /// [everywhere] is the difference between the two intents behind one button.
  /// Off, this is local housekeeping: the manifest simply stops claiming rows
  /// this device no longer holds, and another device's copy is untouched. On, it
  /// asserts the data is wrong, and the writer's chunks stay as tombstones so
  /// the deletion travels. This is the one case where a chunk may shrink.
  ///
  /// Local deletion alone does not keep the rows away. A writer that is still
  /// switched on is re-imported from Health Connect, and once a delegate exists,
  /// re-pulled from the backend. Switching the writer off is what makes either
  /// stick, which is why the switch and this action are separate.
  Future<void> deleteApp(
    String package, {
    bool vacuum = false,
    bool everywhere = false,
  }) async {
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
      await txn.delete(
        HealthSchema.nutrition,
        where: 'app = ?',
        whereArgs: [appId],
      );
      if (everywhere) {
        await txn.update(
          HealthSchema.chunk,
          {
            'deleted': 1,
            'dirty': 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'app = ?',
          whereArgs: [appId],
        );
      } else {
        await txn.delete(
          HealthSchema.chunk,
          where: 'app = ?',
          whereArgs: [appId],
        );
      }
      await txn.rawUpdate(
        'UPDATE ${txn.nameTable(HealthSchema.type)} SET history_done = 0 '
        'WHERE type IN (SELECT type FROM '
        '${txn.nameTable(HealthSchema.typeApp)} WHERE app = ?)',
        [appId],
      );
    });
    await rebuildDaily();
    // VACUUM cannot run inside a transaction, and it rewrites the whole shared
    // app database rather than only this tool's tables.
    if (vacuum) await db.execute('VACUUM');
  }

  /// Drops every row nothing can read any more and rewrites the file.
  ///
  /// "Unused" is deliberately narrow, and means exactly three things:
  ///
  /// 1. Rows written by a globally switched-off app. Every read filters those
  ///    out and the rollups skip them, so they are dead weight until the writer
  ///    is switched back on - which is why this is destructive and confirmed.
  /// 2. Session parts whose session is gone.
  /// 3. Interned text no session or part references any more.
  ///
  /// A switched-off *data type* keeps its rows: reads filter by metric, not by
  /// Health Connect type, so that data is still on the dashboard. Rollups are
  /// rebuilt afterwards, which also drops rollup rows for metrics left empty.
  ///
  /// Always local, never a tombstone, and it needs no exclusion list: this only
  /// ever touches writers that are globally switched off, and a switched-off
  /// writer is not pulled from the backend either. Reclaiming the space cannot
  /// therefore be undone by the next sync run, and cannot reach another device.
  Future<HealthPruneResult> pruneUnused() async {
    final db = await _db();
    var rows = 0;
    var text = 0;
    if (_disabledApps.isNotEmpty) {
      final disabled = _disabledApps.join(', ');
      await db.transaction((txn) async {
        final sessions = txn.nameTable(HealthSchema.session);
        rows += await txn.rawDelete(
          'DELETE FROM ${txn.nameTable(HealthSchema.sessionPart)} '
          'WHERE session IN (SELECT id FROM $sessions WHERE app IN ($disabled))',
        );
        rows += await txn.rawDelete(
          'DELETE FROM $sessions WHERE app IN ($disabled)',
        );
        rows += await txn.rawDelete(
          'DELETE FROM ${txn.nameTable(HealthSchema.point)} '
          'WHERE app IN ($disabled)',
        );
        rows += await txn.rawDelete(
          'DELETE FROM ${txn.nameTable(HealthSchema.interval)} '
          'WHERE app IN ($disabled)',
        );
        await txn.rawDelete(
          'DELETE FROM ${txn.nameTable(HealthSchema.chunk)} '
          'WHERE app IN ($disabled)',
        );
      });
    }
    await db.transaction((txn) async {
      final sessions = txn.nameTable(HealthSchema.session);
      final parts = txn.nameTable(HealthSchema.sessionPart);
      rows += await txn.rawDelete(
        'DELETE FROM $parts WHERE session NOT IN (SELECT id FROM $sessions)',
      );
      text += await txn.rawDelete(
        'DELETE FROM ${txn.nameTable(HealthSchema.text)} WHERE id NOT IN ('
        'SELECT activity FROM $sessions WHERE activity IS NOT NULL '
        'UNION SELECT title FROM $sessions WHERE title IS NOT NULL '
        'UNION SELECT part FROM $parts WHERE part IS NOT NULL)',
      );
    });
    await rebuildDaily();
    // Interned ids the delete pass removed are still cached, so the text
    // dimension is reloaded before anything reads through it again.
    _textIds.clear();
    _textValues.clear();
    await _loadDimensions(db);
    // VACUUM cannot run in a transaction, and it rewrites the whole shared app
    // database rather than only this tool's tables.
    await db.execute('VACUUM');
    return HealthPruneResult(rows: rows, text: text);
  }

  /// Clears the full-import completion flag for [types], so the importer reads
  /// their history again instead of skipping them. Needed whenever a writer is
  /// added back to a type that already finished importing without it.
  /// The pinned window goes with the flag. Keeping `range_end` behind would make
  /// the next import resume over the range the finished one already covered, so
  /// it could never reach anything written since - which is how re-enabling a
  /// source replayed old data and missed today's.
  Future<void> resetTypeHistory(Iterable<String> types) async {
    if (types.isEmpty) return;
    final db = await _db();
    final placeholders = List.filled(types.length, '?').join(', ');
    await db.rawUpdate(
      'UPDATE ${db.nameTable(HealthSchema.type)} SET history_done = 0, '
      'range_start = NULL, range_end = NULL '
      'WHERE type IN ($placeholders)',
      types.toList(),
    );
  }

  /// Wipes the imported data so the next import reads it back from scratch.
  ///
  /// Under backend sync this is a **local rebuild**, not a deletion, and the
  /// manifest and cursor go with the rows. An empty manifest has nothing to
  /// push, so the next run pulls every server chunk back and the Health Connect
  /// re-import adds this device's share on top. Keeping either behind would say
  /// the opposite - that this device already shipped data it no longer holds -
  /// and the server copy would never come home.
  Future<void> clearImportedData() async {
    final db = await _db();
    await db.transaction((txn) async {
      for (final table in [...HealthSchema.dataTables, HealthSchema.chunk]) {
        await txn.delete(table);
      }
      await txn.executor.delete(
        'tool_settings',
        where: 'tool_id = ? AND key LIKE ?',
        whereArgs: [HealthDashboardTool.config.id, 'sync_cursor_%'],
      );
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
    return rows.map(HealthTypeState.fromMap).toList();
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

  Future<HealthTypeState?> typeRow(String type) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.type,
      where: 'type = ?',
      whereArgs: [type],
      limit: 1,
    );
    return rows.isEmpty ? null : HealthTypeState.fromMap(rows.single);
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
    bool allowed(Map<String, Object?> row) =>
        (row['enabled'] as int) == 1 &&
        !_disabledApps.contains(row['app'] as int);
    if (rows.every(allowed)) return const [];
    return rows
        .where(allowed)
        .map((row) => _appPackages[row['app'] as int])
        .whereType<String>()
        .toList();
  }

  /// Writers that must not contribute to [type] - switched off for this type, or
  /// switched off globally. The full importer expresses this as a `dataOrigins`
  /// filter, but the change sync cannot: `synchronize()` takes no origin filter,
  /// so it has to drop the records itself.
  Future<Set<String>> excludedPackages(String type) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.typeApp,
      columns: ['app', 'enabled'],
      where: 'type = ?',
      whereArgs: [type],
    );
    final excluded = <String>{
      for (final id in _disabledApps)
        if (_appPackages[id] != null) _appPackages[id]!,
    };
    for (final row in rows) {
      if ((row['enabled'] as int) == 1) continue;
      final package = _appPackages[row['app'] as int];
      if (package != null) excluded.add(package);
    }
    return excluded;
  }

  Future<void> setTypeAppEnabled({
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

  // --- global app switch and priority ---------------------------------------

  /// Every known writer, best priority first. Row counts are omitted here
  /// because counting a writer's dense rows is an index scan over millions of
  /// entries - [appRowCounts] does that separately so a settings list can paint
  /// before it finishes.
  Future<List<HealthAppState>> apps() async {
    final db = await _db();
    final rows = await db.query(HealthSchema.app, orderBy: 'prio ASC, id ASC');
    final typeCounts = <int, int>{};
    for (final row in await db.rawQuery(
      'SELECT app, COUNT(*) AS n FROM ${db.nameTable(HealthSchema.typeApp)} '
      'WHERE enabled = 1 GROUP BY app',
    )) {
      typeCounts[row['app'] as int] = (row['n'] as num?)?.toInt() ?? 0;
    }
    return rows
        .map(
          (row) => HealthAppState(
            appId: row['id'] as int,
            package: row['package'] as String,
            enabled: (row['enabled'] as int? ?? 1) == 1,
            prio: (row['prio'] as num?)?.toInt() ?? HealthSchema.defaultPrio,
            typeCount: typeCounts[row['id'] as int] ?? 0,
          ),
        )
        .toList();
  }

  /// Stored rows per writer. Separate from [apps] because it scans the dense
  /// tables' `(app, metric)` indexes.
  Future<Map<int, int>> appRowCounts() async {
    final db = await _db();
    final counts = <int, int>{};
    for (final table in [
      HealthSchema.point,
      HealthSchema.interval,
      HealthSchema.nutrition,
      HealthSchema.session,
    ]) {
      for (final row in await db.rawQuery(
        'SELECT app, COUNT(*) AS n FROM ${db.nameTable(table)} GROUP BY app',
      )) {
        final appId = row['app'] as int;
        counts[appId] =
            (counts[appId] ?? 0) + ((row['n'] as num?)?.toInt() ?? 0);
      }
    }
    return counts;
  }

  /// Turns a writer off everywhere. The rows it already contributed are **kept**
  /// - they stop being read and stop feeding the rollups, and come back
  /// instantly if the writer is switched on again. Reclaiming the space is a
  /// separate, explicit [deleteApp].
  ///
  /// The rollups are the caller's to rebuild - see [setAppOrder].
  Future<void> setAppEnabled(String package, bool enabled) async {
    final db = await _db();
    final appId = _appIds[package];
    if (appId == null) return;
    await db.update(
      HealthSchema.app,
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [appId],
    );
    if (enabled) {
      _disabledApps.remove(appId);
    } else {
      _disabledApps.add(appId);
    }
  }

  /// Reorders writers. [order] is best-first; positions become the stored
  /// priority, so the list the user sees is the list the rollups use.
  ///
  /// The rollups are **not** rebuilt here, though priority decides which writer
  /// each day is computed from and they do have to be. Rebuilding reads the
  /// whole store, and only the caller knows whether a run of arrow taps has
  /// settled - see `HealthDashboardState._scheduleRollupRebuild`.
  Future<void> setAppOrder(List<String> order) async {
    final db = await _db();
    await db.transaction((txn) async {
      for (var index = 0; index < order.length; index++) {
        final appId = _appIds[order[index]];
        if (appId == null) continue;
        await txn.update(
          HealthSchema.app,
          {'prio': index},
          where: 'id = ?',
          whereArgs: [appId],
        );
        _appPrio[appId] = index;
      }
    });
  }

  // --- backup ---------------------------------------------------------------

  static const _backupMarkerTable = 'health_backup_marker';

  /// Copies this tool's tables into a standalone database file at [path]. The
  /// work happens inside SQLite, so nothing is materialised as Dart objects and
  /// the cost is bounded by disk rather than by row count.
  ///
  /// The caller passes the final destination, so the file is written once
  /// instead of being built in temp and copied afterwards.
  Future<void> exportBackupTo(
    String path, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await _db();
    final file = File(path);
    // ATTACH wants to create the file itself, and a picked destination may
    // already hold an older backup.
    if (await file.exists()) await file.delete();
    // Progress is weighted by rows: two dense tables carry nearly every byte, so
    // counting tables would leave the bar still for the whole run.
    final counts = <String, int>{};
    var total = 0;
    for (final table in HealthSchema.backupTables) {
      final rows = await _countRows(db, table);
      counts[table] = rows;
      total += rows;
    }
    onProgress?.call(0, total);
    await db.execute('ATTACH DATABASE ? AS backup', [path]);
    try {
      // The backup is rebuilt from scratch whenever anything fails, so a journal
      // and per-transaction fsyncs only buy a second full write of the file.
      // Both go through rawQuery: a PRAGMA that reports its resulting value is a
      // query, and sqflite rejects it on the execute path.
      await db.rawQuery('PRAGMA backup.journal_mode = OFF');
      await db.rawQuery('PRAGMA backup.synchronous = OFF');
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
        await db.execute(await _backupTableDdl(db, table));
        await db.execute(
          'INSERT INTO backup.$table SELECT * FROM ${db.nameTable(table)}',
        );
        processed += counts[table] ?? 0;
        onProgress?.call(processed, total);
      }
    } finally {
      await db.execute('DETACH DATABASE backup');
    }
  }

  /// The live `CREATE TABLE` of [table], retargeted at the backup file. Read out
  /// of `sqlite_master` rather than restated here, so the backup always carries
  /// the real definition - primary keys, `WITHOUT ROWID` and all - and cannot
  /// drift when the schema changes. Indexes are deliberately left out: they cost
  /// export time and file size, and the import rebuilds them by writing into the
  /// live tables.
  Future<String> _backupTableDdl(ToolDatabase db, String table) async {
    final named = db.nameTable(table);
    final rows = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      [named],
    );
    return (rows.single['sql'] as String).replaceFirst(named, 'backup.$table');
  }

  Future<int> _countRows(ToolDatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${db.nameTable(table)}',
    );
    return (rows.single['n'] as num?)?.toInt() ?? 0;
  }

  /// Reads a backup's marker without touching the stored data, so an unusable
  /// file is rejected before the user is asked to agree to a wipe.
  Future<HealthBackupInfo> readBackupInfo(String path) async {
    final probe = await openDatabase(path, readOnly: true);
    try {
      final marker = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [_backupMarkerTable],
      );
      if (marker.isEmpty) {
        throw const FormatException('Not a Health Dashboard backup.');
      }
      final rows = await probe.rawQuery('SELECT * FROM $_backupMarkerTable');
      final row = rows.isEmpty ? const <String, Object?>{} : rows.first;
      final exportedAt = (row['exported_at'] as num?)?.toInt();
      return HealthBackupInfo(
        schemaVersion: (row['schema_version'] as num?)?.toInt() ?? 1,
        exportedAt: exportedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(exportedAt),
      );
    } finally {
      await probe.close();
    }
  }

  /// Replaces the stored data with the backup's contents.
  ///
  /// Destructive by design: a backup is a whole snapshot, and a merge could
  /// never drop rows the user removed after taking it. Columns are matched by
  /// name, so a file written by an older schema still restores and its missing
  /// columns keep their defaults.
  Future<int> importBackup(
    String path, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final info = await readBackupInfo(path);
    if (info.isNewerThanApp) {
      throw HealthBackupTooNewException(info.schemaVersion);
    }
    final db = await _db();
    final total = HealthSchema.backupTables.length;
    var processed = 0;
    var imported = 0;
    onProgress?.call(0, total);
    await db.execute('ATTACH DATABASE ? AS backup', [path]);
    try {
      // One transaction: an interrupted restore leaves the previous data intact
      // rather than a half-replaced store.
      await db.transaction((txn) async {
        for (final table in HealthSchema.backupTables) {
          await txn.execute('DELETE FROM ${txn.nameTable(table)}');
          final columns = await _sharedColumns(txn, table);
          if (columns.isNotEmpty) {
            final list = columns.join(', ');
            imported += await txn.rawUpdate(
              'INSERT OR REPLACE INTO ${txn.nameTable(table)} ($list) '
              'SELECT $list FROM backup.$table',
            );
          }
          onProgress?.call(++processed, total);
        }
      });
    } finally {
      await db.execute('DETACH DATABASE backup');
    }
    // A file written before session identity existed restores with the column
    // empty, and the manifest is not in the backup at all - it describes what
    // this device owes the backend, which a snapshot cannot know. Both are
    // derived from the rows that just landed.
    await db.transaction((txn) async {
      await HealthSchema.backfillDedupeKeys(txn);
      await HealthSchema.rebuildChunkManifest(txn);
    });
    // The restored file brings its own dimension rows, so the interning caches
    // are stale.
    reset();
    await _db();
    // Always: the rollups are keyed by local midnight, so they only ever mean
    // something on the machine that computed them. An older file may also be
    // missing columns the reduction now reads.
    await rebuildDaily();
    return imported;
  }

  /// Columns [table] has in both the live schema and the backup file. An older
  /// export is missing the newer ones; a table the export never had yields an
  /// empty list and is simply left empty, which is what a restore means.
  Future<List<String>> _sharedColumns(
    ToolDatabaseExecutor db,
    String table,
  ) async {
    final local = await _columnNames(db, 'main', db.nameTable(table));
    final backup = await _columnNames(db, 'backup', table);
    return local.where(backup.contains).toList();
  }

  Future<Set<String>> _columnNames(
    ToolDatabaseExecutor db,
    String schema,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA $schema.table_info($table)');
    return {for (final row in rows) row['name'] as String};
  }

  // --- backend sync ---------------------------------------------------------

  /// The whole manifest, including chunks this device declines to carry: the
  /// engine reads local metadata to decide what to pull, and a declined chunk
  /// has to look settled or every run would fetch it again. Declined rows are
  /// never push candidates, because they are never dirty and their stamp is
  /// exactly the server's.
  Future<List<HealthChunkMeta>> chunkManifest({bool onlyDirty = false}) async {
    final db = await _db();
    final rows = await db.query(
      HealthSchema.chunk,
      where: onlyDirty ? 'dirty = 1' : null,
    );
    final result = <HealthChunkMeta>[];
    for (final row in rows) {
      final package = _appPackages[row['app'] as int];
      // A manifest row whose writer is gone from the dimension table cannot be
      // named in a chunk id, so it cannot travel.
      if (package == null) continue;
      result.add(
        HealthChunkMeta(
          day: row['day'] as int,
          package: package,
          updatedAt: row['updated_at'] as int,
          dirty: (row['dirty'] as int) == 1,
          deleted: (row['deleted'] as int) == 1,
        ),
      );
    }
    return result;
  }

  /// Everything one writer wrote inside one UTC day, read out of the tables
  /// rather than out of whatever an import produced.
  ///
  /// That distinction is the whole correctness argument for the chunk. Rows
  /// pulled from another device are in here too, so a push is always a superset
  /// of what the sender knew; serializing an import batch instead would let the
  /// thinner device overwrite the fuller one on the server.
  ///
  /// Carries plain strings, never interned ids - one device's `metric = 3` is
  /// another's `metric = 7` - and no Health Connect record ids, which name a
  /// record in the sender's Health Connect and mean nothing in the receiver's.
  Future<Map<String, dynamic>?> chunkPayload(int day, String package) async {
    final db = await _db();
    final appId = _appIds[package];
    if (appId == null) return null;
    final from = day * HealthSchema.chunkDayMillis;
    final to = from + HealthSchema.chunkDayMillis;
    final metricKeys = {for (final e in _metricIds.entries) e.value: e.key};

    final points = await db.query(
      HealthSchema.point,
      columns: ['metric', 't', 'v', 'v2'],
      where: 'app = ? AND t >= ? AND t < ?',
      whereArgs: [appId, from, to],
    );
    final intervals = await db.query(
      HealthSchema.interval,
      columns: ['metric', 't0', 't1', 'v'],
      where: 'app = ? AND t0 >= ? AND t0 < ?',
      whereArgs: [appId, from, to],
    );
    final sessions = await db.query(
      HealthSchema.session,
      where: 'app = ? AND t0 >= ? AND t0 < ?',
      whereArgs: [appId, from, to],
    );
    final nutrition = await db.query(
      HealthSchema.nutrition,
      where: 'app = ? AND t0 >= ? AND t0 < ?',
      whereArgs: [appId, from, to],
    );

    final sessionPayloads = <Map<String, dynamic>>[];
    for (final row in sessions) {
      final parts = await db.query(
        HealthSchema.sessionPart,
        where: 'session = ?',
        whereArgs: [row['id'] as int],
        orderBy: 'seq ASC',
      );
      sessionPayloads.add({
        'kind': row['kind'],
        't0': row['t0'],
        't1': row['t1'],
        'activity': ?_textValues[row['activity'] as int? ?? -1],
        'title': ?_textValues[row['title'] as int? ?? -1],
        if (row['notes'] != null) 'notes': row['notes'],
        if (row['client_id'] != null) 'clientId': row['client_id'],
        if (row['distance_km'] != null) 'distanceKm': row['distance_km'],
        if (row['calories'] != null) 'calories': row['calories'],
        if (row['steps'] != null) 'steps': row['steps'],
        if (row['avg_hr'] != null) 'avgHr': row['avg_hr'],
        if (row['max_hr'] != null) 'maxHr': row['max_hr'],
        if (row['avg_speed'] != null) 'avgSpeed': row['avg_speed'],
        if (row['max_speed'] != null) 'maxSpeed': row['max_speed'],
        if (row['asleep_min'] != null) 'asleepMin': row['asleep_min'],
        if (parts.isNotEmpty)
          'parts': [
            for (final part in parts)
              [
                part['kind'],
                _textValues[part['part'] as int? ?? -1],
                part['t0'],
                part['t1'],
                part['v'],
              ],
          ],
      });
    }

    // Dense rows travel packed. Paired readings stay in the plain list: only
    // blood pressure carries a `v2`, there are a handful of them, and keeping
    // them out costs less than teaching the packer a second optional series.
    final packablePoints = <List<Object?>>[];
    final plainPoints = <List<Object?>>[];
    for (final row in points) {
      final metric = metricKeys[row['metric'] as int];
      if (metric == null) continue;
      if (row['v2'] != null) {
        plainPoints.add([metric, row['t'], row['v'], row['v2']]);
      } else {
        packablePoints.add([metric, row['t'], row['v']]);
      }
    }
    final packableIntervals = <List<Object?>>[];
    for (final row in intervals) {
      final metric = metricKeys[row['metric'] as int];
      if (metric == null) continue;
      packableIntervals.add([metric, row['t0'], row['t1'], row['v']]);
    }
    final packedPoints = HealthChunkCodec.encodePoints(packablePoints);
    final packedIntervals = HealthChunkCodec.encodeIntervals(packableIntervals);

    return {
      'day': day,
      'package': package,
      // Positional rather than keyed, for the same reason the packed form
      // exists at all: the field names would outweigh the values.
      'points': plainPoints,
      'intervals': const <List<Object?>>[],
      if (packedPoints != null) 'pointsPacked': _blob(packedPoints),
      if (packedIntervals != null) 'intervalsPacked': _blob(packedIntervals),
      'sessions': sessionPayloads,
      'nutrition': [
        for (final row in nutrition)
          {
            't0': row['t0'],
            't1': row['t1'],
            if (row['client_id'] != null) 'clientId': row['client_id'],
            if (row['food_name'] != null) 'foodName': row['food_name'],
            if (row['meal_type'] != null) 'mealType': row['meal_type'],
            if (row['energy_kcal'] != null) 'energyKcal': row['energy_kcal'],
            if (row['protein_g'] != null) 'proteinG': row['protein_g'],
            if (row['carbohydrate_g'] != null)
              'carbohydrateG': row['carbohydrate_g'],
            if (row['fat_g'] != null) 'fatG': row['fat_g'],
          },
      ],
    };
  }

  /// The wire format the backend stores as a real `BLOB` rather than as base64
  /// text, and that `SyncService._unwrapBlobData` hands back as a plain base64
  /// string on the way in.
  static Map<String, dynamic> _blob(String base64Data) => {
    '__type': 'blob',
    'mimeType': 'application/octet-stream',
    'data': base64Data,
  };

  /// Merges a pulled chunk into the tables, through the same write path an
  /// import uses, so content primary keys collapse what is already here and the
  /// session dedupe rule catches the one table that cannot.
  ///
  /// The manifest afterwards is the subtle part. A chunk that was already dirty
  /// stays dirty and takes a stamp newer than the server's: this device holds
  /// rows the sender did not, and nothing else would ever carry them back. A
  /// chunk that was clean adopts the server's stamp and settles - everything it
  /// held was already pushed, so the sender's copy is a superset and the two
  /// sides now agree. Marking a clean chunk dirty instead would have the two
  /// devices push it to each other forever.
  Future<void> applyChunk({
    required int day,
    required String package,
    required Map<String, dynamic> data,
    required int serverUpdatedAt,
  }) async {
    final knownApp = _appIds[package];
    if (knownApp != null && _disabledApps.contains(knownApp)) {
      await _writeChunkMeta(
        day: day,
        appId: knownApp,
        updatedAt: serverUpdatedAt,
        dirty: false,
        skipped: true,
      );
      return;
    }

    final wasDirty = await _isChunkDirty(day, package);
    final records = _recordsFromChunk(package, data);
    if (records.isNotEmpty) await writeRecords(records);

    final appId = _appIds[package];
    if (appId == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _writeChunkMeta(
      day: day,
      appId: appId,
      // Not `now` alone: a device whose clock trails the sender's would write a
      // stamp the engine reads as older, and pull the same chunk every run.
      updatedAt: wasDirty ? max(now, serverUpdatedAt + 1) : serverUpdatedAt,
      dirty: wasDirty,
      skipped: false,
    );
  }

  List<HealthMappedRecord> _recordsFromChunk(
    String package,
    Map<String, dynamic> data,
  ) {
    // Both forms are read. A sender that predates the packed encoding, or one
    // whose paired readings could not be packed, puts rows in the plain lists;
    // the blob arrives already unwrapped to base64 by the sync engine.
    final points = <HealthPointRow>[];
    final packedPoints = data['pointsPacked'];
    for (final row in [
      ...?data['points'] as List<dynamic>?,
      if (packedPoints is String)
        ...HealthChunkCodec.decodePoints(packedPoints),
    ]) {
      final values = row as List<dynamic>;
      final metric = values[0] as String?;
      if (metric == null || !HealthMetrics.has(metric)) continue;
      points.add(
        HealthPointRow(
          metric: metric,
          t: (values[1] as num).toInt(),
          v: (values[2] as num).toDouble(),
          v2: (values.length > 3 ? values[3] as num? : null)?.toDouble(),
        ),
      );
    }
    final intervals = <HealthIntervalRow>[];
    final packedIntervals = data['intervalsPacked'];
    for (final row in [
      ...?data['intervals'] as List<dynamic>?,
      if (packedIntervals is String)
        ...HealthChunkCodec.decodeIntervals(packedIntervals),
    ]) {
      final values = row as List<dynamic>;
      final metric = values[0] as String?;
      if (metric == null || !HealthMetrics.has(metric)) continue;
      intervals.add(
        HealthIntervalRow(
          metric: metric,
          t0: (values[1] as num).toInt(),
          t1: (values[2] as num).toInt(),
          v: (values[3] as num).toDouble(),
        ),
      );
    }

    final records = <HealthMappedRecord>[];
    if (points.isNotEmpty || intervals.isNotEmpty) {
      records.add(
        HealthMappedRecord(
          package: package,
          points: points,
          intervals: intervals,
        ),
      );
    }
    for (final row in data['sessions'] as List<dynamic>? ?? const []) {
      final session = row as Map<String, dynamic>;
      records.add(
        HealthMappedRecord(
          package: package,
          session: HealthSessionRow(
            kind: (session['kind'] as num).toInt(),
            t0: (session['t0'] as num).toInt(),
            t1: (session['t1'] as num).toInt(),
            activity: session['activity'] as String?,
            title: session['title'] as String?,
            notes: session['notes'] as String?,
            clientId: session['clientId'] as String?,
            distanceKm: (session['distanceKm'] as num?)?.toDouble(),
            calories: (session['calories'] as num?)?.toDouble(),
            steps: (session['steps'] as num?)?.toInt(),
            avgHr: (session['avgHr'] as num?)?.toDouble(),
            maxHr: (session['maxHr'] as num?)?.toDouble(),
            avgSpeed: (session['avgSpeed'] as num?)?.toDouble(),
            maxSpeed: (session['maxSpeed'] as num?)?.toDouble(),
            asleepMin: (session['asleepMin'] as num?)?.toInt(),
            parts: [
              for (final part in session['parts'] as List<dynamic>? ?? const [])
                HealthSessionPartRow(
                  kind: ((part as List<dynamic>)[0] as num).toInt(),
                  part: part[1] as String?,
                  t0: (part[2] as num?)?.toInt(),
                  t1: (part[3] as num?)?.toInt(),
                  v: (part[4] as num?)?.toDouble(),
                ),
            ],
          ),
        ),
      );
    }
    for (final row in data['nutrition'] as List<dynamic>? ?? const []) {
      final meal = row as Map<String, dynamic>;
      records.add(
        HealthMappedRecord(
          package: package,
          nutrition: HealthNutritionRow(
            t0: (meal['t0'] as num).toInt(),
            t1: (meal['t1'] as num).toInt(),
            clientId: meal['clientId'] as String?,
            foodName: meal['foodName'] as String?,
            mealType: meal['mealType'] as String?,
            energyKcal: (meal['energyKcal'] as num?)?.toDouble(),
            proteinG: (meal['proteinG'] as num?)?.toDouble(),
            carbohydrateG: (meal['carbohydrateG'] as num?)?.toDouble(),
            fatG: (meal['fatG'] as num?)?.toDouble(),
          ),
        ),
      );
    }
    return records;
  }

  /// Clears a chunk's dirty flag once the backend has it. [deleted] means the
  /// deletion is now the agreed state, whether this device asserted it or
  /// another one did, so the rows go here too - applying a deletion twice is
  /// harmless, and skipping it would leave a tombstoned chunk holding data.
  Future<void> finalizeChunk(int day, String package, bool deleted) async {
    final appId = _appIds[package];
    if (appId == null) return;
    if (!deleted) {
      final db = await _db();
      await db.update(
        HealthSchema.chunk,
        {'dirty': 0},
        where: 'day = ? AND app = ?',
        whereArgs: [day, appId],
      );
      return;
    }
    await _deleteChunkRows(day, appId);
    await _writeChunkMeta(
      day: day,
      appId: appId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: false,
      deleted: true,
      skipped: false,
    );
  }

  /// Forgets that this device declined a writer's chunks, so re-admitting the
  /// writer pulls its history back instead of leaving the manifest claiming the
  /// chunks are settled.
  Future<void> clearSkippedChunks(String package) async {
    final appId = _appIds[package];
    if (appId == null) return;
    final db = await _db();
    await db.delete(
      HealthSchema.chunk,
      where: 'app = ? AND skipped = 1',
      whereArgs: [appId],
    );
  }

  Future<bool> _isChunkDirty(int day, String package) async {
    final appId = _appIds[package];
    if (appId == null) return false;
    final db = await _db();
    final rows = await db.query(
      HealthSchema.chunk,
      columns: ['dirty'],
      where: 'day = ? AND app = ?',
      whereArgs: [day, appId],
      limit: 1,
    );
    return rows.isNotEmpty && (rows.first['dirty'] as int) == 1;
  }

  Future<void> _writeChunkMeta({
    required int day,
    required int appId,
    required int updatedAt,
    required bool dirty,
    required bool skipped,
    bool deleted = false,
  }) async {
    final db = await _db();
    await db.insert(HealthSchema.chunk, {
      'day': day,
      'app': appId,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
      'deleted': deleted ? 1 : 0,
      'skipped': skipped ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _deleteChunkRows(int day, int appId) async {
    final db = await _db();
    final from = day * HealthSchema.chunkDayMillis;
    final to = from + HealthSchema.chunkDayMillis;
    final touched = <int, Set<int>>{};
    for (final row in await db.query(
      HealthSchema.point,
      columns: ['metric', 't'],
      where: 'app = ? AND t >= ? AND t < ?',
      whereArgs: [appId, from, to],
    )) {
      (touched[row['metric'] as int] ??= <int>{}).add(dayKey(row['t'] as int));
    }
    for (final row in await db.query(
      HealthSchema.interval,
      columns: ['metric', 't0'],
      where: 'app = ? AND t0 >= ? AND t0 < ?',
      whereArgs: [appId, from, to],
    )) {
      (touched[row['metric'] as int] ??= <int>{}).add(dayKey(row['t0'] as int));
    }
    await db.transaction((txn) async {
      final sessions = txn.nameTable(HealthSchema.session);
      await txn.rawDelete(
        'DELETE FROM ${txn.nameTable(HealthSchema.sessionPart)} '
        'WHERE session IN (SELECT id FROM $sessions '
        'WHERE app = ? AND t0 >= ? AND t0 < ?)',
        [appId, from, to],
      );
      await txn.delete(
        HealthSchema.session,
        where: 'app = ? AND t0 >= ? AND t0 < ?',
        whereArgs: [appId, from, to],
      );
      await txn.delete(
        HealthSchema.point,
        where: 'app = ? AND t >= ? AND t < ?',
        whereArgs: [appId, from, to],
      );
      await txn.delete(
        HealthSchema.interval,
        where: 'app = ? AND t0 >= ? AND t0 < ?',
        whereArgs: [appId, from, to],
      );
      await txn.delete(
        HealthSchema.nutrition,
        where: 'app = ? AND t0 >= ? AND t0 < ?',
        whereArgs: [appId, from, to],
      );
      await _refreshDaily(txn, touched);
    });
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

import 'package:tool_lab/services/database_service.dart';

/// Typed store for Health Connect data.
///
/// Design rules, in priority order:
///
/// 1. Nothing numeric is stored as JSON. Every value the dashboard reads is a
///    real column with a real type.
/// 2. Text that repeats across fact rows is interned to an integer and joined
///    back: writing app, activity name, session title, sleep stage. Text that
///    is genuinely unique per row (a Health Connect record id, freeform notes)
///    stays inline, where a dimension table would only add a join.
/// 3. Dense tables are `WITHOUT ROWID` with the measurement itself as the
///    primary key, so no surrogate key is stored at all. The previous schema
///    gave every sample a TEXT primary key holding base64 of
///    `<metric>|<time>|<value>` - roughly 60 bytes re-encoding the row's own
///    contents, plus its index, times three million rows.
/// 4. The dashboard reads `health_daily`, never the dense tables.
class HealthSchema {
  HealthSchema._();

  /// Version 1 was a fresh ladder; the pre-typed schema reached 10 and is
  /// dropped outright rather than migrated - see
  /// `HealthStore._dropPreTypedSchema`. Version 2 adds the global per-app switch
  /// and priority.
  static const version = 2;

  static const metric = 'health_metric';
  static const app = 'health_app';
  static const text = 'health_text';
  static const point = 'health_point';
  static const interval = 'health_interval';
  static const session = 'health_session';
  static const sessionPart = 'health_session_part';
  static const daily = 'health_daily';
  static const type = 'health_type';
  static const typeApp = 'health_type_app';

  /// Starting priority for a newly discovered writer. Mid-range so the user can
  /// promote or demote without renumbering everything.
  static const defaultPrio = 100;

  static const sessionKindExercise = 0;
  static const sessionKindSleep = 1;

  static const partKindSleepStage = 0;
  static const partKindLap = 1;

  /// Tables carrying imported data, ordered so a delete pass can walk them
  /// without tripping over references.
  static const dataTables = [daily, sessionPart, session, point, interval];

  /// Everything this tool owns, for the backup table copy. Dimension tables are
  /// included: without them the interned integers in a restored backup resolve
  /// to nothing.
  static const backupTables = [
    metric,
    app,
    text,
    point,
    interval,
    session,
    sessionPart,
    daily,
    type,
    typeApp,
  ];

  static Future<void> create(ToolDatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE ${db.nameTable(metric)} (
        id INTEGER PRIMARY KEY,
        key TEXT NOT NULL UNIQUE,
        unit TEXT NOT NULL,
        agg INTEGER NOT NULL,
        shape INTEGER NOT NULL
      )
    ''');
    // `enabled` is global, unlike the per-type switch in health_type_app: a
    // disabled writer is neither pulled nor counted anywhere. `prio` orders
    // writers against each other - lower wins - and decides which single app a
    // day's rollup is computed from. Not named `rank`, which SQLite also uses as
    // a window function.
    await db.execute('''
      CREATE TABLE ${db.nameTable(app)} (
        id INTEGER PRIMARY KEY,
        package TEXT NOT NULL UNIQUE,
        label TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        prio INTEGER NOT NULL DEFAULT $defaultPrio
      )
    ''');
    // One intern table for every enum-like string, shared across categories so
    // 'running' is stored once whether it arrives as an activity or a lap kind.
    await db.execute('''
      CREATE TABLE ${db.nameTable(text)} (
        id INTEGER PRIMARY KEY,
        value TEXT NOT NULL UNIQUE
      )
    ''');
    // The primary key IS the measurement. Two apps writing the same value at the
    // same instant collapse to one row on insert, which is what removes the
    // Google Fit mirror of a direct writer without any comparison pass.
    await db.execute('''
      CREATE TABLE ${db.nameTable(point)} (
        metric INTEGER NOT NULL,
        t INTEGER NOT NULL,
        v REAL NOT NULL,
        v2 REAL,
        app INTEGER NOT NULL,
        PRIMARY KEY (metric, t, v)
      ) WITHOUT ROWID
    ''');
    // Carries `origin` unlike health_point: interval records are orders of
    // magnitude fewer, and a deleted steps or distance record has to be able to
    // leave the daily totals.
    await db.execute('''
      CREATE TABLE ${db.nameTable(interval)} (
        metric INTEGER NOT NULL,
        t0 INTEGER NOT NULL,
        t1 INTEGER NOT NULL,
        v REAL NOT NULL,
        app INTEGER NOT NULL,
        origin TEXT,
        PRIMARY KEY (metric, t0, t1, v)
      ) WITHOUT ROWID
    ''');
    // Summary columns are denormalised at import so a workout list renders from
    // this table alone, with no reach into the dense tables.
    await db.execute('''
      CREATE TABLE ${db.nameTable(session)} (
        id INTEGER PRIMARY KEY,
        kind INTEGER NOT NULL,
        activity INTEGER,
        title INTEGER,
        notes TEXT,
        t0 INTEGER NOT NULL,
        t1 INTEGER NOT NULL,
        app INTEGER NOT NULL,
        origin TEXT NOT NULL UNIQUE,
        client_id TEXT,
        distance_km REAL,
        calories REAL,
        steps INTEGER,
        avg_hr REAL,
        max_hr REAL,
        avg_speed REAL,
        max_speed REAL,
        asleep_min INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE ${db.nameTable(sessionPart)} (
        session INTEGER NOT NULL,
        seq INTEGER NOT NULL,
        kind INTEGER NOT NULL,
        part INTEGER,
        t0 INTEGER,
        t1 INTEGER,
        v REAL,
        PRIMARY KEY (session, seq)
      ) WITHOUT ROWID
    ''');
    // The dashboard's read table. A decade of ~30 metrics is ~110k rows, so
    // every card, weekly chart and all-time total is a primary key seek.
    await db.execute('''
      CREATE TABLE ${db.nameTable(daily)} (
        metric INTEGER NOT NULL,
        day INTEGER NOT NULL,
        total REAL,
        avg REAL,
        lo REAL,
        hi REAL,
        n INTEGER NOT NULL,
        PRIMARY KEY (metric, day)
      ) WITHOUT ROWID
    ''');
    // Per-type selection and full-import progress in one row. range_start and
    // range_end pin the window an interrupted full import was covering, so it
    // resumes over the same range instead of drifting with the clock.
    await db.execute('''
      CREATE TABLE ${db.nameTable(type)} (
        type TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL DEFAULT 0,
        history_done INTEGER NOT NULL DEFAULT 0,
        range_start INTEGER,
        range_end INTEGER,
        n INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      ) WITHOUT ROWID
    ''');
    // Discovered writers per type, and whether the user pulls from them. The
    // enabled set becomes the dataOrigins filter on the read request, so an
    // unselected writer's rows are never handed to us in the first place.
    await db.execute('''
      CREATE TABLE ${db.nameTable(typeApp)} (
        type TEXT NOT NULL,
        app INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        n INTEGER NOT NULL DEFAULT 0,
        last_t INTEGER,
        PRIMARY KEY (type, app)
      ) WITHOUT ROWID
    ''');
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_session_time')} '
      'ON ${db.nameTable(session)} (kind, t0)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_session_app')} '
      'ON ${db.nameTable(session)} (app)',
    );
    // Deleting every row a deselected writer contributed, and provenance
    // filters on charts, both start from the app.
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_point_app')} '
      'ON ${db.nameTable(point)} (app, metric)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_interval_app')} '
      'ON ${db.nameTable(interval)} (app, metric)',
    );
  }

  /// Adds the global per-app switch and priority to an existing v1 store.
  /// Existing writers stay enabled at the default priority, so the rollups keep
  /// the meaning they had until the user actually picks a primary source.
  static Future<void> migrateToV2(ToolDatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${db.nameTable(app)} '
      'ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE ${db.nameTable(app)} '
      'ADD COLUMN prio INTEGER NOT NULL DEFAULT $defaultPrio',
    );
  }

  static Future<void> drop(ToolDatabaseExecutor db) async {
    for (final table in [
      daily,
      sessionPart,
      session,
      point,
      interval,
      typeApp,
      type,
      text,
      app,
      metric,
    ]) {
      await db.execute('DROP TABLE IF EXISTS ${db.nameTable(table)}');
    }
  }
}

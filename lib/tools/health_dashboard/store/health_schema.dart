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
  /// and priority. Version 3 adds device-independent session identity and the
  /// backend sync manifest. Version 4 adds what reading a chunk out of the dense
  /// tables needs, and the marker for a chunk this device declines to carry.
  static const version = 4;

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
  static const chunk = 'health_chunk';

  /// A chunk day is UTC, unlike `HealthStore.dayKey`, which is local midnight.
  /// The chunk is a sync partition, not something the user reads, and two
  /// devices in different timezones have to cut the same rows the same way.
  static const chunkDayMillis = 86400000;

  static int chunkDay(int millis) => millis ~/ chunkDayMillis;

  /// Starting priority for a newly discovered writer. Mid-range so the user can
  /// promote or demote without renumbering everything.
  static const defaultPrio = 100;

  /// Device-independent identity for a session row.
  ///
  /// `origin` cannot serve: it is the Health Connect record id, assigned by the
  /// Health Connect instance that stored the row, so the same workout carries a
  /// different one on every device and a pulled copy would insert beside the
  /// local one. The writer's own [clientId] is stable across devices wherever it
  /// is set - every treadmill workout has one - and the composite covers the
  /// third-party writers that set none.
  static String dedupeKey({
    required int kind,
    required int t0,
    required int t1,
    required String package,
    String? clientId,
  }) => clientId != null && clientId.isNotEmpty
      ? 'c:$clientId'
      : 'k:$kind|$t0|$t1|$package';

  static const sessionKindExercise = 0;
  static const sessionKindSleep = 1;

  static const partKindSleepStage = 0;
  static const partKindLap = 1;

  /// Tables carrying imported data, ordered so a delete pass can walk them
  /// without tripping over references.
  static const dataTables = [daily, sessionPart, session, point, interval];

  /// Everything this tool owns, for the backup table copy. Dimension tables are
  /// included: without them the interned integers in a restored backup resolve
  /// to nothing. [daily] is deliberately absent - its `day` is local midnight of
  /// the machine that computed it, so a rollup restored in another timezone keys
  /// on a midnight the reader never looks up. The restore derives it instead.
  static const backupTables = [
    metric,
    app,
    text,
    point,
    interval,
    session,
    sessionPart,
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
    await _createSession(db);
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
    await _createChunk(db);
    await _createSessionIndexes(db);
    await _createChunkReadIndexes(db);
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

  /// Summary columns are denormalised at import so a workout list renders from
  /// this table alone, with no reach into the dense tables. `origin` is nullable
  /// and no longer unique: it is per-device provenance, and a row that only ever
  /// arrived through a sync chunk has no local Health Connect record to name.
  /// Identity is [dedupeKey].
  static Future<void> _createSession(ToolDatabaseExecutor db) async {
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
        origin TEXT,
        dedupe_key TEXT,
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
  }

  static Future<void> _createSessionIndexes(ToolDatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_session_time')} '
      'ON ${db.nameTable(session)} (kind, t0)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_session_app')} '
      'ON ${db.nameTable(session)} (app)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX ${db.nameTable('idx_health_session_dedupe')} '
      'ON ${db.nameTable(session)} (dedupe_key)',
    );
    // Origin lost its UNIQUE constraint and with it the implicit index that
    // deleting by Health Connect record id relied on.
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_health_session_origin')} '
      'ON ${db.nameTable(session)} (origin)',
    );
  }

  /// What this device owes the backend, one row per (UTC day, writer). Exists so
  /// the sync metadata phase never scans `health_point`. `dirty` is set by the
  /// importer whenever rows actually landed for the pair, and cleared once the
  /// chunk has been pushed.
  static Future<void> _createChunk(ToolDatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE ${db.nameTable(chunk)} (
        day        INTEGER NOT NULL,
        app        INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty      INTEGER NOT NULL DEFAULT 1,
        deleted    INTEGER NOT NULL DEFAULT 0,
        skipped    INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (day, app)
      ) WITHOUT ROWID
    ''');
  }

  /// Serializing a chunk asks for one writer's rows inside one UTC day. The
  /// existing `(app, metric)` indexes cannot answer that without walking every
  /// row that writer ever wrote, which is the dense table in full.
  static Future<void> _createChunkReadIndexes(ToolDatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ${db.nameTable('idx_health_point_app_t')} '
      'ON ${db.nameTable(point)} (app, t)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ${db.nameTable('idx_health_interval_app_t')} '
      'ON ${db.nameTable(interval)} (app, t0)',
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

  /// Session identity and the sync manifest.
  ///
  /// The session table is rebuilt rather than altered: `origin` has to lose both
  /// `NOT NULL` and `UNIQUE`, and SQLite cannot drop a constraint in place. The
  /// manifest is filled from the data already stored and marked dirty, so this
  /// device's existing history is what the first sync run offers the server.
  static Future<void> migrateToV3(ToolDatabaseExecutor db) async {
    await _createChunk(db);

    const columns =
        'id, kind, activity, title, notes, t0, t1, app, origin, client_id, '
        'distance_km, calories, steps, avg_hr, max_hr, avg_speed, max_speed, '
        'asleep_min';
    final sessions = db.nameTable(session);
    final previous = db.nameTable('${session}_v2');
    await db.execute('ALTER TABLE $sessions RENAME TO $previous');
    // The old indexes followed the table through the rename and would collide
    // with the new ones by name.
    await db.execute(
      'DROP INDEX IF EXISTS ${db.nameTable('idx_health_session_time')}',
    );
    await db.execute(
      'DROP INDEX IF EXISTS ${db.nameTable('idx_health_session_app')}',
    );
    await _createSession(db);
    await db.execute(
      'INSERT INTO $sessions ($columns) SELECT $columns FROM $previous',
    );
    await db.execute('DROP TABLE $previous');

    await backfillDedupeKeys(db);
    await _createSessionIndexes(db);

    await rebuildChunkManifest(db);
  }

  /// What serializing and declining a chunk need. `skipped` marks a chunk this
  /// device has seen on the server and deliberately does not carry, because its
  /// writer is switched off here - without it every run would re-pull the same
  /// chunks and throw them away again.
  static Future<void> migrateToV4(ToolDatabaseExecutor db) async {
    // A store coming from v2 gets the current chunk table out of migrateToV3
    // and already has the column; one coming from v3 does not.
    final columns = await db.rawQuery(
      'PRAGMA table_info(${db.nameTable(chunk)})',
    );
    final hasSkipped = columns.any((row) => row['name'] == 'skipped');
    if (!hasSkipped) {
      await db.execute(
        'ALTER TABLE ${db.nameTable(chunk)} '
        'ADD COLUMN skipped INTEGER NOT NULL DEFAULT 0',
      );
    }
    await _createChunkReadIndexes(db);
  }

  /// Fills [dedupeKey] for every session that has none, and drops the rows that
  /// turn out to be the same session twice. Also the repair after a backup
  /// written by an older schema is restored.
  ///
  /// A pre-v3 store can hold two rows that resolve to one identity - the import
  /// path only merged what its overlap check caught - so this has to leave a set
  /// the unique index can be built over. `UPDATE OR IGNORE` matters when the
  /// index already exists: the second row of a pair keeps a null key instead of
  /// failing the statement, and is then removed with the rest.
  ///
  /// The survivor is the copy carrying the most parts, not the lowest id. Parts
  /// go with the row they hang off, and a re-import does not bring them back:
  /// the import path leaves a session alone when its summary columns already
  /// match, so a discarded copy's sleep stages would simply be gone.
  static Future<void> backfillDedupeKeys(ToolDatabaseExecutor db) async {
    final sessions = db.nameTable(session);
    await db.execute(
      "UPDATE OR IGNORE $sessions SET dedupe_key = COALESCE("
      "'c:' || NULLIF(client_id, ''), "
      "'k:' || kind || '|' || t0 || '|' || t1 || '|' || "
      "COALESCE((SELECT package FROM ${db.nameTable(app)} AS a "
      "WHERE a.id = $sessions.app), '?')"
      ') WHERE dedupe_key IS NULL',
    );
    final keep =
        'SELECT (SELECT y.id FROM $sessions AS y WHERE y.dedupe_key = g.dedupe_key '
        'ORDER BY (SELECT COUNT(*) FROM ${db.nameTable(sessionPart)} AS p '
        'WHERE p.session = y.id) DESC, y.id LIMIT 1) '
        'FROM (SELECT DISTINCT dedupe_key FROM $sessions '
        'WHERE dedupe_key IS NOT NULL) AS g';
    final duplicates =
        'SELECT id FROM $sessions '
        'WHERE dedupe_key IS NULL OR id NOT IN ($keep)';
    await db.execute(
      'DELETE FROM ${db.nameTable(sessionPart)} WHERE session IN ($duplicates)',
    );
    await db.execute('DELETE FROM $sessions WHERE id IN ($duplicates)');
  }

  /// Derives the whole manifest from the stored rows, every chunk dirty. Used
  /// where local data appears without going through the importer - the v3
  /// migration, and a backup restore.
  static Future<void> rebuildChunkManifest(ToolDatabaseExecutor db) async {
    await db.execute('DELETE FROM ${db.nameTable(chunk)}');
    await db.execute(
      'INSERT INTO ${db.nameTable(chunk)} (day, app, updated_at, dirty, deleted) '
      'SELECT day, app, ?, 1, 0 FROM ('
      'SELECT t / $chunkDayMillis AS day, app FROM ${db.nameTable(point)} '
      'UNION SELECT t0 / $chunkDayMillis, app FROM ${db.nameTable(interval)} '
      'UNION SELECT t0 / $chunkDayMillis, app FROM ${db.nameTable(session)})',
      [DateTime.now().millisecondsSinceEpoch],
    );
  }

  static Future<void> drop(ToolDatabaseExecutor db) async {
    for (final table in [
      chunk,
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

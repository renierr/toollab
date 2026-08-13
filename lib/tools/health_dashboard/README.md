# Health Dashboard Implementation Context

The narrative reference for the storage model is `docs/storage-model.html`, next
to this file. This document is the working context: what the tool is for, which
rules are load-bearing, and what is known to be unfinished.

## Product Goal

One canonical Health Dashboard data set shared by Android phone, Android tablet
and Windows. Android reads every selected Health Connect type; the backend syncs
the result to devices that have no Health Connect at all, so Windows renders the
same visualisations without ever talking to it. Nothing is written back to
Health Connect.

The tool must keep the evidence of where a measurement came from while never
showing or summing the same measurement twice.

### Vendor neutrality

No rule may hardcode a writer package. Google Fit, Zepp/Amazfit and Renpho
appear below only as the observed data that validated the rules. Every decision
keys off record identity, timestamps, client-id shape, measured priority or
explicit user preference, so it works for any other user's devices.

`lib/tools/health_dashboard/health_source_apps.dart` maps packages to friendly
names and icons for display only. It is presentation, never a rule input, and an
unrecognised writer falls back to its package name rather than to a generic
label.

## Storage Model

The typed store is the only storage. Nothing numeric is a JSON blob; repeated
text is interned to an integer and joined back.

| Table | Purpose |
| --- | --- |
| `health_metric` | Metric catalogue: unit, aggregation, shape. |
| `health_app` | Writing app. Also carries the global on/off switch and `prio`. |
| `health_text` | Interned labels: activity, session title, sleep stage. |
| `health_point` | Instant measurements. `PRIMARY KEY (metric, t, v)`. |
| `health_interval` | Range values - steps, distance, energy. `PRIMARY KEY (metric, t0, t1, v)`. |
| `health_session` | Sleep and exercise containers with denormalised summaries. |
| `health_session_part` | Sleep stages and laps. |
| `health_daily` | The dashboard's read table: one reduced row per metric and day. |
| `health_type` | Per-type pull selection plus full-import progress. |
| `health_type_app` | Discovered writers per type, and whether that type is pulled from them. |

Both dense tables are `WITHOUT ROWID` with the measurement itself as the primary
key, so no surrogate key is stored and two writers recording the same value at
the same instant collapse to one row on insert.

**Aggregates read `health_daily`, never the dense tables.** A decade of ~30
metrics is on the order of a hundred thousand rows, so every card, weekly chart
and all-time total is a primary-key seek.

`health_daily.day` is the epoch millis of **local midnight**, and readers look a
day up by exact key (`dayKey()`), never by a range. Every writer therefore has to
produce the same instant. The incremental refresh uses `dayKey`/`dayBounds`; the
full rebuild groups in SQL and needs the trailing `'utc'` in
`strftime('%s', datetime(t, 'localtime', 'start of day'), 'utc')`. Without it
SQLite returns the local wall clock read as if it were UTC - the same number only
where the offset is zero. On a UTC device the two agree and nothing shows; move
the same data to a machine at UTC+2 and every rebuilt rollup lands two hours off
the key its reader asks for, so the drilldown charts read nothing while the raw
history still lists every row.

The pre-typed schema - `health_source_records` with a `payload_json` blob, its
write-only normalised children, and the even earlier `records` cache - is gone.
It is dropped outright rather than migrated, detected by a stored schema version
higher than the current one. Everything in it came from Health Connect and is
re-importable.

## Source Selection

Three controls, easy to confuse, deliberately distinct:

| Control | Where | Effect |
| --- | --- | --- |
| Per-type enable | `health_type.enabled` | Whether the type is read at all. A type nobody selects costs nothing. |
| Per-type source | `health_type_app.enabled` | Whether this type is read from that writer. Becomes a `dataOrigins` filter. |
| Global app switch | `health_app.enabled` | Whether the writer counts anywhere: not pulled, not read, not aggregated. |

Plus **priority** (`health_app.prio`, lower wins), which does not exclude
anything - it decides who wins when two writers describe the same thing.

Types and writers only exist once discovery has registered them. Discovery is a
bounded probe: a recent window, a few pages per type. It exists to populate the
selection screens, and it never changes an existing choice.

### Switching a source off keeps its rows

Disabling stops a writer being pulled and drops it out of every read and
rollup. The rows it already contributed stay, so switching it back on is
instant and free. Reclaiming the disk is a separate, explicit action - "Clean up and
shrink database" - because deleting rows does not shrink the file on its own:
SQLite frees the pages and reuses them, so the delete path has to `VACUUM` to
hand the space back.

Anything that re-admits a writer to a type must clear that type's
`history_done`. Otherwise the importer skips the finished type and the newly
allowed writer's history is never read.

## The Health Connect Settings Screen

Every entry either changes what gets pulled, moves data in, or deletes data.
Nothing on it shows or hides anything on the dashboard - the dashboard renders
whatever survived the pull and the rollup. `docs/storage-model.html` §11 has the
same table plus a diagram of where each gate cuts.

| Entry | Does | Touches |
| --- | --- | --- |
| Manage Health Connect | Leaves the app for Health Connect's own screen, to inspect or revoke read permission. Granting does not happen here. | nothing |
| Data types | Per-type pull switch. A type that is off is never read at all. | `health_type.enabled` |
| Apps | Global per-writer switch plus the priority order. Off means neither pulled, read nor aggregated; stored rows stay. | `health_app.enabled`, `prio` |
| Scan available data | Bounded probe that registers which types hold data and which apps wrote it. Populates the two screens above; changes no existing choice. | `health_type`, `health_type_app` |
| Sync changes on open | Runs the change-token sync on every tool open. Off means data arrives only from a manual import. | `tool_settings` |
| Import selected data | Full history for every enabled type. **Resumes** - a finished type is skipped, an unfinished one re-reads its stored range. | fact tables, per-type progress |
| Sync changes now | The change-token sync on demand, including deletions. | fact tables, sync token |
| Re-import from scratch | Empties every fact table, clears all progress, reads all history again from 1970. | fact tables, per-type progress |
| Clean up and shrink database | Deletes rows nothing can read any more, then `VACUUM`s. Confirmed, irreversible. | rows of switched-off apps, orphan parts, unused `health_text` |

### Re-import from scratch does clear the tables first

`clearImportedData()` deletes every row of `health_daily`,
`health_session_part`, `health_session`, `health_point` and `health_interval` in
one transaction, then resets `history_done`, `range_start`, `range_end` and `n`
on every type. **Selection survives**: types, discovered writers, app switches
and priority are all kept, so the re-read pulls exactly what is selected now. It
does not `VACUUM`, because the freed pages are reused by the rows coming back in.

### Clean up: what counts as unused

Only three things, and deliberately not more:

1. Rows written by a **globally switched-off app**. Every read filters them out
   and the rollups skip them, so they are dead weight - which is also why this is
   destructive: re-admitting that writer afterwards needs a fresh import.
2. Session parts whose session is gone.
3. Interned `health_text` no session or part references any more.

A switched-off **data type** keeps its rows. Reads filter by metric, not by
Health Connect type, so that data is still on the dashboard and is not unused.
Rollups are rebuilt afterwards, which also drops rollup rows for metrics left
empty, and then the file is rewritten with `VACUUM`.

### The per-app Health Connect screen cannot be opened

`android.health.connect.action.MANAGE_HEALTH_PERMISSIONS` with `EXTRA_PACKAGE_NAME`
resolves - to `com.google.android.healthconnect.controller`'s `SettingsActivity` -
but starting it throws `SecurityException: ... requires
android.permission.GRANT_RUNTIME_PERMISSIONS`. It is the deep link the system's
own settings use, and no ordinary app can hold a signature permission. Measured
on an Android 14 emulator, none of `androidx.health.ACTION_HEALTH_CONNECT_SETTINGS`,
`android.health.connect.action.HEALTH_CONNECT_SETTINGS` or
`android.settings.HEALTH_CONNECT_SETTINGS` resolves either, so the cascade ends at
Health Connect's launcher entry and then at app info, which the UI now states
rather than silently landing the user somewhere unexpected.

**Granting is a separate mechanism.** Read access comes from the permission
request sheet raised by `HealthConnectImporter.requestAccess()`. Every entry that
reads Health Connect calls it first, and offers the Health Connect screen when
nothing is granted instead of reporting a successful import of zero records.

### Why a switched-off app could still land in a full import

The `dataOrigins` filter Health Connect accepts is an **allowlist only**, and the
list can only be built from the writers discovery attributed to a type. Because
discovery is a bounded probe, the filter is sent empty - "no restriction" -
whenever every *known* writer for a type is allowed; building it from discovery
instead made a full import return almost nothing (see Duplicates, rule 1).

So a writer switched off globally that discovery never saw under some type is not
in that type's list, the filter goes empty, and Health Connect hands its records
over. They never appeared on the dashboard, but they were stored. The importer
now drops excluded packages as records arrive as well - the same thing the change
sync always had to do, since `synchronize()` accepts no origin filter.

## Duplicates

A republisher writes other apps' data into the local store, so a device with
both a direct writer and a republisher sees most measurements twice. Four
mechanisms, in the order they apply:

1. **Don't read it.** A deselected writer becomes a `dataOrigins` filter, so
   Health Connect never hands over its rows. Filtering beats deduplicating.
   The filter may only ever **exclude**: it is sent only when something is
   actually switched off. Building it from discovery instead - treating a
   bounded probe as the complete writer list - made a full import return
   nothing but the app that had written most recently.
2. **Collide on insert.** An identical value at an identical instant cannot
   produce two rows, given the primary key.
3. **One writer per day per metric.** A day's rollup is computed from a single
   writer: best `prio`, then most rows that day, then lowest id. Summing across
   writers was the real cause of inflated step and distance totals - a
   republisher re-buckets the same walk into different intervals, so the rows
   are not byte-identical, the primary key cannot collapse them, and both landed
   in the total. Averages had the same problem more quietly, with `n`, `lo` and
   `hi` mixing two streams.
4. **Priority decides session mirrors.** A session already stored for the same
   kind and exact range by another writer is a mirror; the better-ranked writer
   keeps the slot, and ties keep the first writer.

Choosing the day's winner **per day** rather than globally is what keeps a
republisher useful. On a day no other writer covered, it wins by default and its
data still shows up.

### Why blanket-excluding a republisher is wrong

It is not merely a mirror. It can be the only writer holding data for a device
that never saw the original, and it can carry data whose origin has no local
writer at all. In the captured data the tablet is a full republished copy for
dense metrics - 274,188/274,188 heart-rate rows and 2000/2000 sampled speed rows
match the phone exactly - yet it is still the only source of 104 weight and 104
body-fat rows. Deduplicate and rank; never exclude wholesale.

### Never merge on device metadata

A user may own two physical scales that Health Connect cannot tell apart - they
can even present the same device id. Only an exact `(metric, t, v)` collision
may collapse such measurements.

## Measured Evidence

From captured phone and tablet analysis databases. These are the numbers the
rules above were validated against.

### Cross-device record identity

| Data | Shares original record id across devices? |
| --- | ---: |
| Exercise sessions | 624 / 626 |
| Sleep sessions | 152 / 167 |
| heart_rate_series, speed_series, steps, weight | **0 / 891,805** |

Session containers keep one id across devices; dense samples get a fresh id per
device. That is why samples are keyed on the measurement rather than on the
record that carried it.

### Republished vs direct data on one phone

Exact timestamp comparisons, direct writer against republisher:

| Metric | Exact matches | Result |
| --- | ---: | --- |
| Exercise sessions | 92 | Same range; enum representation differs. |
| Speed samples | 2,488 | Mean delta 0.03 km/h. |
| Weight | 104 | Mean delta 0.026 kg, maximum 0.05 kg. |
| Steps | 2,701 | Identical values. |
| Sleep sessions | 106 | Identical session marker. |
| Heart-rate samples | 7,768 | Mean delta 1.13 bpm. |

**Near-mirrors never collapse.** A 1.13 bpm mean delta means those rows are
legitimately distinct values and both persist. This is why priority matters more
than insert-time collision does: only ranking removes a near-mirror from an
aggregate.

More rows are not evidence of independent physical measurements. The republisher
had 1,084,472 heart-rate rows against the watch writer's 390,830.

### The client-id mirror rule

An earlier revision claimed the signal was "the direct writer's client id ends
with the republisher's client id". That only holds for exercise, where the
republisher's client id happens to be a bare timestamp:

| Type | Direct id ends with republisher id | Both ids end with `start_time` |
| --- | ---: | ---: |
| Exercise | 305 / 305 | 308 detected |
| Sleep | **0 / 328** | 343 detected |

The rule that holds for both: two records from **different** writers describing
the same `start_time` are a mirror when the trailing digit run of each
`client_record_id` is identical. Trailing-token conformance was 333/333 and
526/526 for the direct writer, 1502/1554 and 354/354 for the republisher; the
exercise shortfall is segmented sub-sessions, whose client id embeds the
parent's timestamp.

## Import Paths

`HealthConnectImporter.import` is the full-history read, and
`HealthConnectDiff.sync` is the incremental one. Both write through
`HealthStore.writeRecords`, which refreshes only the rollups its page touched,
in the same transaction as the facts.

Import everything selected, not sessions only:

- Containers: sleep and exercise sessions plus their stages and laps.
- Instants: heart rate, HRV, SpO2, respiratory rate, weight, body fat, speed,
  cadence. These must be readable outside a session, for example HR over time.
- Intervals: steps, distance, calories and similar ranges.
- Session drilldowns query the same rows by time range. Sessions never own
  copied metric data.

### Staying alive while it runs

Every read is a platform call into another process, and a full history is minutes
of them. Discovery, the full import, the change sync, the cleanup and the backup
export all hold a `BackgroundWorkLease` for their duration - a partial (CPU) wake
lock plus a foreground notification - so Doze or app standby cannot suspend the
app halfway through and leave a type stranded mid-range.

None of this can move to a background isolate: the plugin's method channels are
bound to the main isolate, so a spawned one cannot reach Health Connect at all.
Keeping the process scheduled is the isolation that is available.

### Paging

Paging follows `response.nextPageRequest`. The plugin exposes **no** page token
on the read response; a previous version read one through `dynamic` and threw
`NoSuchMethodError` before the first page was written. The per-type catch
swallowed it, so a full-history import finished in seconds, reported success and
stored nothing. **If an import ever completes suspiciously fast, check this
first.**

Page requests are opaque objects and cannot be persisted, so an interrupted type
resumes from its stored range start rather than mid-page. The upserts make that
idempotent. An import where *every* type failed throws rather than reporting
success with zero records - that is what a revoked read permission looks like.

### Incremental sync

Built on Health Connect's own change tracking, `synchronize(dataTypes,
syncToken)`. A trailing time window could not be correct: a watch that uploads
Tuesday's data on Thursday writes *behind* any watermark, and a window cannot
observe deletions at all.

Three states it must handle: no token yet (establishing a baseline returns no
records by design - report it as a baseline, never as "nothing changed"); a
scope change, since the token is bound to its type list; and expiry, which
throws `InvalidArgumentException` and needs a full import.

`synchronize` takes **no** `dataOrigins` filter, so this path has to drop
excluded writers itself. Without that, a source the user switched off returns on
every open.

Deletions can only be matched against rows carrying the Health Connect record
id, which is sessions and intervals. Storing that id on every one of millions of
dense samples would cost more than the schema saves.

## Measured Performance

Phone, full history, roughly 3M records: **13 seconds per 5,000 records, and the
rate stays constant** as the tables grow. Constant rate is the check that
matters - a decaying rate means something is scanning. Four fixes got it there
and must stay:

- Duplicate detection used `ABS(start_time - ?) <= 5000`, which no index can
  answer. It is a sargable `BETWEEN` range now.
- Dense series skip duplicate detection entirely. Their measurements already
  collapse on the primary key, so pairing carrier records off against every
  other record of the same type found nothing and cost the most.
- Samples are written in one batched commit per record, not one `db.insert` per
  sample - that is one platform-channel round trip each.
- `health_app` is not touched per record. Its contents do not change between
  records of the same package.

## Backup

A SQLite file is the only backup format. Scoped to this tool and done inside
SQLite, so nothing is materialised as Dart objects and the cost is bounded by
disk rather than by row count:

```sql
ATTACH DATABASE ? AS backup;
PRAGMA backup.journal_mode = OFF;   -- a file rebuilt on failure needs no journal
CREATE TABLE backup.<t> (...);      -- the live DDL, read from sqlite_master
INSERT INTO backup.<t> SELECT * FROM tool_health_dashboard_<t>;
```

### The backup's DDL is copied, never restated

`_backupTableDdl` reads the `CREATE TABLE` out of `sqlite_master` and retargets
the name at the `backup` schema. The file therefore always carries the real
definition - primary keys, `WITHOUT ROWID` and all - and cannot drift when the
schema changes. Indexes are deliberately left out: they cost export time and file
size, and the import rebuilds them by writing into the live tables.

### The export writes straight to its destination

The caller resolves the final path first - a desktop save dialog, or the public
Downloads folder on Android - and the store writes there. Only when Android
cannot give a direct path (no all-files access) does the file go to temp and get
copied afterwards. That copy is headless, so an export that finishes while the
app is in the background still lands in Downloads instead of waiting for a
picker. Both directions hold a `BackgroundWorkLease`.

### Import is destructive

Every table is emptied and refilled from the backup, in one transaction. A merge
was the old behaviour and could never remove rows deleted after the backup was
taken; a snapshot restore can. A marker table carries the tool id and schema
version: a foreign file and a file from a newer schema are both rejected before
the user is asked to confirm the wipe.

Columns are matched by name (`_sharedColumns`), never by position, so a file
written by an older schema still restores and its missing columns keep their
defaults. `SELECT *` would break the moment a column was added.

`health_daily` is not in `backupTables` and is always rebuilt by the restore. Its
`day` is local midnight of the machine that computed it, so a rollup carried to a
device in another timezone keys on a midnight `dailyRange` never asks for - the
drilldown charts read nothing while the raw history still lists every row. It is
derived data, so re-deriving it locally is both correct and cheaper than shipping
it. The change token
is dropped after every restore - it describes changes against a dataset we no
longer hold, so the next sync establishes a fresh baseline.

The whole-app database export is separate and unaffected.

## Sync Design

The backend stays generic. Do not create a Health-specific API or Health backend
tables. Canonical entities are ordinary generic sync records whose ids carry a
generation; bump it whenever identity changes, and ids of another generation
resolve to no table and are dropped on pull.

Do not sync dashboard UI caches or per-device import progress. Restoring
progress would claim data was imported on a device that never read it.

Backend specifics live in `browser-toolkit`: bounded metadata pages with a
keyset cursor, record and request-size limits on push and pull, and a change log
pruned on an interval rather than per upsert.

## Operating It

**Which import entry to use.** "Import selected data" resumes unfinished types.
"Re-import from scratch" empties the fact tables and re-reads from the beginning,
keeping the selection. After anything that leaves progress stamped but the tables
empty, use the re-import. Full table above in The Health Connect Settings
Screen.

**When backend sync happens.** Never during an import. The import entries
contain no backend call at all. It runs from the app's global Sync Now and from
the dashboard's own toolbar action, through `HealthSyncDelegate`, which ships one
record per (UTC day, writer) rather than per reading. See
`docs/backend-sync-plan.md` for the chunk design and `storage-model.html` for the
tables it rests on.

**The toolbar action does both, in that order.** Publish pending treadmill
workouts, read Health Connect changes, then sync the backend. The engine pulls
before it pushes, so a chunk is serialized over a table that already holds both
this device's fresh import and the other device's rows, and the push is a true
superset. Reversing the two would ship a chunk missing what the import was about
to add. On Windows the Health Connect step is skipped rather than reported as a
missing permission - there is no permission to be missing there, and that screen's
data arrives entirely through the backend.

**Parallel devices.** Phone and tablet may import simultaneously; the imports
are independent. Avoid syncing both at the same moment - a large sync is
thousands of requests against one SQLite backend, and a tripped timeout means
the work is redone.

Sanity checks after a second device joins: workout count must not roughly
double, and heart-rate point counts must not jump about 2x. Either means the
dedup rules are not firing.

## Generated Test Data (debug builds only)

An emulator holds no health data, which makes most of the dashboard impossible
to look at. `HealthDebugSeeder` writes a synthetic history into Health Connect;
the entry sits at the bottom of the Health Connect settings screen behind
`kDebugMode`, so it is absent from a release build entirely.

### How to use it

1. **Dashboard → settings (gear) → Health Connect settings → Generated test
   data.** Debug builds only; the tile is not compiled into a release build.
2. **Pick a range** (7 / 30 / 90 / 180 / 365 days) and a **preset**. A preset only
   ticks a set of groups - adjust the checkboxes afterwards if you want
   something narrower. Grant the write permissions Health Connect asks for.
3. **Generate data**, confirm. It runs under a `BackgroundWorkLease`, so a year
   of everything survives the screen going off. A year of all seven groups is
   roughly 13k records and a couple of minutes; 90 days is a few thousand.
4. Back on the Health Connect settings screen: **Scan sources**, then **Import
   selected data**. Generated data is just another writer, so it arrives on the
   ordinary import path. Step 4 alone is enough on an emulator that has no other
   writers (see below).
5. **Remove generated data** wipes what the generator wrote - and only that -
   then generate again. Nothing else has to be reset in between.

Writing needs the matching `WRITE_*` permission **declared in the manifest**, not
just granted: an undeclared one makes `requestPermissions` throw
`PERMISSION_NOT_DECLARED` rather than come back denied. The eighteen the
generator needs beyond the treadmill publisher's six live in
`android/app/src/debug/AndroidManifest.xml`, so they merge into debug builds
only and a release never asks for write access to weight, sleep or blood
pressure. Keep that list in step with `HealthDebugSeeder._typesByGroup`, and
remember a manifest change needs a full rebuild - hot reload will not pick it up.

Step 4 is why the scan matters: the full importer sends the allowed writers as a
`dataOrigins` allowlist, and that list can only name writers discovery has
already attributed to a type. On a device with other writers present, a
brand-new one is missing from the list until the probe runs again. On an empty
emulator the filter is empty - "no restriction" - and the import finds it either
way.

### How it is built

Seven groups - activity, heart, sleep, workouts, body, vitals, hydration - each
cover one coherent slice of a day, and a preset is nothing but a set of them, so
a preset and a hand-picked selection are the same thing to the generator.

| Group | Records | Cadence |
| --- | --- | --- |
| `activity` | Steps, Distance, ActiveEnergyBurned, TotalEnergyBurned, FloorsClimbed, ElevationGained | 15 hourly step buckets, thirds of a day for distance and energy, daily for the rest |
| `heart` | HeartRateSeries, RestingHeartRate, HeartRateVariabilityRMSSD | Day-long series every 20 min, resting and HRV once in the morning |
| `sleep` | SleepSession with stages, OxygenSaturation, RespiratoryRate, HeartRateVariabilityRMSSD | One night per day, ~6¼–8¼ h; the three curves sampled every 30 min **inside** the session |
| `workouts` | ExerciseSession, SpeedSeries, Distance, ActiveEnergyBurned, Steps | Three a week, picked by the day itself |
| `body` | Weight, BodyFatPercentage, LeanBodyMass, BoneMass, BodyWaterMass, Height | First three every other day, rest weekly |
| `vitals` | OxygenSaturation, RespiratoryRate, BloodPressure, BodyTemperature, BloodGlucose | First three daily as morning readings, temperature weekly, glucose 3× every third day |
| `hydration` | Hydration | Four a day |

Presets: **Everyday** = activity + heart + sleep + body, **Athlete** adds
workouts and hydration, **Clinical** = heart + body + vitals, **Everything** =
all seven.

Two properties matter more than the shapes:

- **Every record carries a client record id** of
  `toollab:health-debug:<epoch day>:<part>`. The prefix is what makes the data
  removable again - the wipe reads the generator's types back, keeps the records
  carrying it and deletes those by id, so real data, treadmill workouts above
  all, is untouched. Time-range deletion would not be able to tell them apart.
- **It gets its own source.** Android attributes every record to the writing
  package, and this app has one, so generated rows would otherwise be labelled
  and switched off as Treadmill Control's real workouts.
  `HealthConnectMapper.packageOf` files anything carrying the prefix under the
  synthetic package `de.renier.tool_lab.generated` (`health_debug_origin.dart`),
  which gives it its own row in Apps, its own switch and priority, and a
  `deleteAppData` that by construction cannot reach anything real. Discovery and
  both exclusion checks resolve the writer through the same helper.
- **The id is derived from the day, not from the run.** Generating the same day
  twice replaces its records instead of adding a second copy, and the per-day
  `Random(epochDay)` seed means a 7 day set and a year set agree on the days they
  share. Feed, clear, feed again converges on the same history.

**Oxygen saturation, respiratory rate and HRV belong to the `sleep` group, not
to `vitals`.** The sleep screen lays them over the session as curves, and a
morning spot reading falls outside it - which left those overlays empty however
many vitals were generated. Sampling them every 30 minutes inside the night, and
keeping them with the group that owns the night, means picking `sleep` alone
still yields a complete one. `vitals` keeps its own daytime readings of the same
two metrics; they coexist, as they would on a real device.

Each group draws from its own `Random(epochDay * 31 + group.index)`, so a
group's shape does not shift depending on what was selected alongside it. The
night window is the exception: `_night(day, epochDay)` is seeded from the day
alone, so the session and its curves agree on the same window.

The values are shapes rather than noise: steps follow a waking-hour curve, heart
rate drops overnight and rises in the evening, sleep runs in ~90 minute cycles,
weight drifts on a sine rather than jittering, and workouts land three times a
week picked by the day itself. Today is written only up to the current time.

A batch that Health Connect rejects is retried one record at a time, so a single
type this platform version will not take costs one record rather than two
hundred. `BodyMassIndexRecord` is deliberately never written - Health Connect
has no such record type.

Clearing also drops the generating package's rows from the store via
`deleteAppData`, because deleting in Health Connect alone would leave everything
already imported behind. Generated data reaches the dashboard the same way any
writer's does: scan sources, then import.

## Sleep Quality Scoring

`health_sleep_quality.dart` starts every night at 100 and deducts for each of
five checks that falls outside a standard adult reference range - duration,
efficiency, deep share, REM share, awake minutes. No weighting, no model. The
bands, a worked example and an interactive scorer live in
[`docs/sleep-quality.html`](docs/sleep-quality.html); that page is the reference
and must be updated whenever a band or a deduction changes.

Two things surprise people, both by design and both documented there: **more**
deep sleep than the reference range costs 5 points, and the number of awakenings
is counted and displayed but never scored - only the awake minutes are. A
6-hour night with three brief wakes, 13 % deep and 24 % REM therefore loses 10
points for duration alone, scores 90 and reads "Good".

The sleep detail page around it - the stage bar, the four switchable curves and
what each block reads from which table - is described in `docs/storage-model.html`
§12, which also carries an interactive copy of the stage chart drawn from the same
layout constants. That section is where detail pages for the other record types
get documented as they grow.

## Known Gaps

- **A full backend sync at full history has never been run.** The chunk design
  removes the reason the old row-per-record sync could not do it, payloads are
  materialised one push batch at a time, and dense rows ship packed rather than
  as JSON - 4.2x measured on 129 real chunks. The claim is still untested at a
  decade of data, and on two devices actually populated.
- Priority defaults to the same value for every writer, so the day-winner rule
  falls back to row count until the user orders the app list. Deriving a default
  order from the measured republisher signal - same `start_time`, matching
  trailing client-id token, later `last_modified` - is not implemented.
- Cross-device dedup has not been observed with two devices actually populated.
  The workout-count and heart-rate-count checks above are the test.
- `exportHealthConnectComparison()` and the exporter's `exportComparison` have
  no caller and no UI. They served the phone-vs-tablet analysis. Wire or delete.
- A history-depth setting: how many years to mirror. Everyone can afford to sync
  notes; not everyone wants a decade of samples.
- Whether dense samples should sync to desktop at all. Excluding them means
  desktop gets every chart and aggregate but no intra-workout heart-rate curves,
  and sync stays small.

### Sync redesign, if it comes to that

Health Connect itself is the reference: a typed relational store with no
row-level cloud sync at all. Its device-to-device story is Backup & restore,
which ships the whole file - a decade of history is ~20 MB that way.

- **Seed by file.** Upload the per-tool backup as one blob; a new device
  restores it in one shot instead of pulling millions of records. Caveat: that
  artifact grows without bound, so it needs a size ceiling, compression, or a
  time window, and a metered connection should not fetch it blindly.
- **Delta by block.** One sync record per `(metric, day)` carrying that day's
  samples. Tens of thousands of blocks rather than millions of rows, and past
  days never change, so coarse last-writer-wins is acceptable for append-only
  history.

Blocking also removes the `canonicalSyncRecords()` memory problem for free.

## Verification

Do not run release builds unless asked.

```text
dart format ./lib
flutter analyze
```

After editing ARB files: `flutter gen-l10n`.

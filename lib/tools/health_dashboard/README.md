# Health Dashboard Implementation Context

## Product Goal

Build one canonical Health Dashboard data set shared by Android Phone, Android
Tablet, and Windows. Android reads every available Health Connect type plus the
Treadmill Control database; the backend syncs the canonical result to devices
that have no Health Connect at all, so Windows renders the same visualisations
without ever talking to Health Connect. Nothing is ever written back to Health
Connect. Never use Google Fit as a transport requirement.

The product must retain source evidence while preventing mirrored source data
from being displayed or aggregated twice.

### Vendor neutrality

No rule may hardcode a writer package. Google Fit, Zepp and Renpho appear below
only as the observed data used to validate the rules; the implementation keys
off record identity, timestamps, client-id shape and user preference so it works
for any other user's devices.

## Device Model

- Each ToolLab installation has a stable `importer_device_id`.
- The Phone and Tablet independently read their local Health Connect stores.
- Both upload canonical entities through the existing generic backend sync.
- Both then download the same union of canonical entities.
- `importer_device_id` is **provenance only and must never be part of canonical
  identity**. It is stored on `health_source_records` (and informationally on
  `health_sources`) but never mixed into a primary key. Including it was the
  original cause of cross-device duplication: the same record read on two
  devices produced two ids, two rows and two sync entities.
- Import checkpoints are device-local and must never sync.

### Measured cross-device identity

From the captured Phone/Tablet analysis databases:

| Data | Shares original record id across devices? |
| --- | ---: |
| Exercise sessions | 624 / 626 |
| Sleep sessions | 152 / 167 |
| heart_rate_series, speed_series, steps, weight | **0 / 891,805** |

Session containers keep one id across devices; dense samples get a fresh id per
device. A single identity rule therefore cannot cover both, which is why
samples are keyed on the measurement instead (see Import Rules).

## Verified Sources

| Writer package | Meaning |
| --- | --- |
| `com.huami.watch.hmwatchmanager` | Direct Zepp/Amazfit writer on Phone. Preferred direct source when a confirmed mirror exists. |
| `com.google.android.apps.fitness` | Google Fit writer. May hold independent data, mirrored Zepp data, and Tablet-only data. Never globally exclude it. |
| `com.renpho.health` | Direct Renpho weight/body composition writer. Health Connect device metadata cannot distinguish two physical scales. Keep timestamped measurements. |
| `de.renier.tool_lab` | ToolLab treadmill publisher. Keep separate from Health Connect source records. |

`metadata.dataOrigin.packageName` identifies the app that wrote the local
Health Connect record. It is not a reliable upstream provenance chain.

## Analysis Evidence

Analysis exports were validated with `PRAGMA integrity_check = ok`.

### Phone full analysis

- 41 readable types.
- 2,877,588 records over 611 pages.
- Range: 2025-08-18 through 2026-08-10.
- Zepp examples: 390,830 HR records, 64,301 HRV, 41,727 SpO2, 142,663
  respiratory-rate records.
- Google Fit examples: 1,084,472 HR and 1,089,250 speed records.

### Tablet comparison

- Google Fit and Renpho only; no direct Zepp writer.
- 601,816 Google Fit rows and 208 Renpho rows in the compact comparison export.
- Google Fit is required as a fallback because it is the only Tablet source for
  many workouts and dense metrics.

### Phone Zepp/Google Fit comparison

Exact timestamp comparisons show Google Fit mirrors substantial direct Zepp
data, but do not prove every Google Fit record comes from Zepp.

| Metric | Exact matches | Result |
| --- | ---: | --- |
| Exercise sessions | 92 | Same time range; enum representation differs. |
| Speed samples | 2,488 | Mean delta 0.03 km/h. |
| Weight | 104 | Mean delta 0.026 kg; maximum 0.05 kg. |
| Steps | 2,701 | Identical values. |
| Sleep sessions | 106 | Identical session marker. |
| Heart-rate samples | 7,768 | Mean delta 1.13 bpm. |

Google Fit has denser and more continuous HR/speed streams. More rows are not
evidence of independent physical measurements.

## Analysis Files And Reproduction Examples

Files used for the evidence above:

```text
C:\Users\renie\Downloads\health_connect_analysis_phone.db
C:\Users\renie\Downloads\health_connect_analysis_tablet.db
C:\Users\renie\Downloads\health_connect_comparison_phone.db
C:\Users\renie\Downloads\health_connect_comparison_tablet.db
```

The complete analysis databases have these important tables:

```text
analysis_run
raw_records
exercise_sessions
type_status
session_record_links   (tablet export only)
```

There is no `type_source_summary` table; an earlier revision of this document
listed one. Inspect `sqlite_master` before writing a query — these exports were
produced by successive versions of the on-device exporter and their schemas
differ. They are also large (1.8 GB phone, 884 MB tablet): query a bounded
subsample, and never join two of them on an unindexed column such as
`source_record_id`.

`raw_records` preserves the Health Connect writer, original record ID, time
range, last-modified time, client ID, recording method, device metadata, and
raw type representation. It is diagnostic-only and must not be uploaded as the
production model.

### List Recent Exercise Writers

Run against either `health_connect_analysis_phone.db` or
`health_connect_analysis_tablet.db`:

```sql
SELECT
  datetime(start_time / 1000, 'unixepoch', 'localtime') AS start,
  datetime(end_time / 1000, 'unixepoch', 'localtime') AS end,
  source_name,
  source_record_id,
  client_record_id,
  device_json
FROM raw_records
WHERE type_id = 'exercise_session'
  AND start_time >= strftime('%s', 'now', '-2 days') * 1000
ORDER BY start_time;
```

Expected result for the 2026-08-08 run/walk:

```text
Phone  Zepp        08:39:32-09:39:46  a532...  ExerciseSessionHCData_1786171172000
Phone  Google Fit  08:39:32-09:39:46  346e...  1786171172000
Tablet Google Fit  08:39:32-09:39:46  346e...  1786171172000
```

This is the strongest currently known cross-device duplicate identity: same
Google Fit original UUID, range, and client ID on Phone and Tablet.

### Inspect A Zepp/Google Fit Session Mirror

Run against the Phone analysis database:

```sql
SELECT
  source_name,
  source_record_id,
  client_record_id,
  start_time,
  end_time,
  last_modified_time
FROM raw_records
WHERE type_id = 'exercise_session'
  AND start_time = 1786171172000
ORDER BY source_name;
```

The result demonstrates the direct Zepp client ID embeds the same timestamp as
the Google Fit client ID. This supports a rule for confirmed session mirrors;
do not apply it to unrelated data types without evidence.

### Compare Type Coverage And Writers

Run against either full analysis database:

```sql
SELECT
  type_id,
  source_name,
  COUNT(*) AS records,
  datetime(MIN(start_time) / 1000, 'unixepoch', 'localtime') AS first_seen,
  datetime(MAX(end_time) / 1000, 'unixepoch', 'localtime') AS last_seen
FROM raw_records
GROUP BY type_id, source_name
ORDER BY type_id, records DESC;
```

Use this to verify that Tablet has no direct Zepp package and that Phone carries
both direct Zepp and Google Fit data.

### Find Same-Range Exercise Candidates

Run against the Phone analysis database:

```sql
SELECT
  zepp.source_record_id AS zepp_id,
  fit.source_record_id AS google_fit_id,
  zepp.client_record_id AS zepp_client_id,
  fit.client_record_id AS google_fit_client_id,
  datetime(zepp.start_time / 1000, 'unixepoch', 'localtime') AS start,
  datetime(zepp.end_time / 1000, 'unixepoch', 'localtime') AS end
FROM raw_records AS zepp
JOIN raw_records AS fit
  ON fit.type_id = zepp.type_id
 AND fit.start_time = zepp.start_time
 AND fit.end_time = zepp.end_time
WHERE zepp.type_id = 'exercise_session'
  AND zepp.source_name = 'com.huami.watch.hmwatchmanager'
  AND fit.source_name = 'com.google.android.apps.fitness';
```

This identifies candidates only. The production decision additionally requires
the client-ID relationship or other matching evidence.

### Compact Comparison Export

The compact comparison files intentionally contain only bounded, structured
Zepp/Google Fit/Renpho metrics for duplicate analysis. They omit raw Health
Connect text and routes. Inspect their actual table names first:

```sql
SELECT name
FROM sqlite_master
WHERE type = 'table'
ORDER BY name;
```

Do not assume the full-analysis `raw_records` schema exists in a comparison
file. The comparison exporter changed during analysis work; inspect its schema
before writing a query. Its purpose is numerical time/value comparison, while
the full analysis database is the source for original IDs and client metadata.

## Confirmed Run/Walk Provenance Example

The 2026-08-08 run/walk proves Google Fit republishes/synchronizes records.

| Device | Writer | Range | Client ID |
| --- | --- | --- | --- |
| Phone | Zepp | 08:39:32-09:39:46 | `ExerciseSessionHCData_1786171172000` |
| Phone | Google Fit | 08:39:32-09:39:46 | `1786171172000` |
| Tablet | Google Fit | 08:39:32-09:39:46 | `1786171172000` |

The Google Fit record UUID is identical on Phone and Tablet:

```text
346e0e47-9fe3-37fa-968a-c3d239d42ca4
```

Google Fit also wrote matching segmented `Run`/`Walk` sessions on both devices.
The Tablet did not obtain a direct Zepp record. Google Fit synchronized its own
record through the Google account and wrote a Google-Fit-owned copy into the
Tablet local Health Connect store. Original Zepp provenance is unavailable
there.

Required duplicate decisions for this example:

1. Same original record id on Phone and Tablet means one logical record, not two
   independent records.
2. The two records are a confirmed mirror because their client record ids carry
   the same trailing numeric token — see the corrected rule below.
3. The record written first wins for effective display/aggregates; the later
   write is the copy.
4. The copy stays as source evidence and as Tablet fallback, but it must not
   create a second workout.

### Corrected mirror rule

An earlier revision of this document claimed the mirror signal was "the Zepp
client id ends with the Google Fit client id". That only holds for exercise,
where the Google Fit client id happens to be a bare timestamp. Measured over the
captured data:

| Type | Zepp id ends with Fit id | Both ids end with `start_time` |
| --- | ---: | ---: |
| Exercise | 305 / 305 | 308 detected |
| Sleep | **0 / 328** | 343 detected |

Sleep fails the old rule entirely because Google Fit writes `Sleep<ts>` there,
not a bare `<ts>`. The rule that holds for both is:

> Two records from **different** sources describing the same `start_time` are a
> mirror when the trailing digit run of each `client_record_id` is identical.

Conformance of the trailing token: 333/333 and 526/526 for the direct writer,
1502/1554 and 354/354 for the republisher. The exercise shortfall is the
segmented sub-sessions, whose client id embeds the parent's timestamp.

Which side loses is decided from the data, not from a package name: the
originator necessarily writes before anything can republish it, so the record
with the later `last_modified_time` is demoted. The per-type source preference
in settings overrides this for display.

## Data Model

The pre-canonical `tool_health_dashboard_records` cache was an analysis-era
table: generic and typed reads mixed, workout JSON embedded copied samples, and
it preserved too little original revision/provenance. It is **dropped in schema
v9** and has no readers or writers. Only its historical migration DDL remains so
installs on v1-v4 can still migrate through.

All tool tables live in the shared app database namespaced `tool_<toolId>_<table>`.

Canonical Health Dashboard tables:

| Table | Purpose |
| --- | --- |
| `health_import_checkpoints` | Local-only per-device/per-type page resume state. Never synced, never backed up. |
| `health_sources` | Writer package. Keyed on `package_name` alone. |
| `health_source_records` | Original record identity, payload, effective decision. |
| `health_sessions` | Sleep, exercise, and treadmill containers. |
| `health_session_details` | Sleep stages, laps, events, route chunks. |
| `health_metric_samples` | Timestamped scalar values, including flattened series samples. |
| `health_interval_metrics` | Steps, distance, calories, activity and other time-range values. |
| `health_duplicate_candidates` | Non-destructive duplicate evidence and decision status. |

### Identity

```text
source        = hash(package_name)
source_record = hash(package_name | original_record_id | type)
sample        = hash(metric_type | time | value)
```

None of these contain the importing device. That is the whole point: the same
record read on two devices must resolve to one row. `importer_device_id` is
stored on `health_source_records` as provenance and is what scopes a
"re-import this device's data" operation - never a source row, since sources are
now shared across devices.

Samples are keyed on the measurement rather than on the record that carried it,
because the carrying record differs per device (0/891,805 shared ids) while the
measurement does not.

### `health_source_records` columns that matter

| Column | Meaning |
| --- | --- |
| `payload_json` | Full original value map. Formerly `import_hash`, which never held a hash. This is what the dashboard projects from, and what travels over sync. |
| `source_kind` | `healthConnect` / `treadmill` / `manual`, stored rather than inferred from a package name. |
| `effective` | `0` marks a demoted mirror. Every dashboard query filters `deleted = 0 AND effective = 1`. |
| `replaced_by_source_record_id` | The winning record of a confirmed mirror. |
| `importer_device_id` | Which installation read it. Provenance only. |

Child data visibility derives from its parent source record. Do not add a
separate effective-record table.

### Read path

The dashboard does not query the canonical tables in their normal shape; it
projects `health_source_records` joined to `health_sources` into the legacy
record shape the UI already consumes. That keeps the widget layer unchanged
while making synced-only devices render. All of it goes through one helper -
add new queries there rather than reaching for a table directly, or a device
without Health Connect will silently show nothing.

### Tool backup

Backup is scoped to this tool and copies tables inside SQLite:

```sql
ATTACH DATABASE ? AS backup;
CREATE TABLE backup.<t> AS SELECT * FROM tool_health_dashboard_<t>;
```

No rows are materialised as Dart objects, so cost is bounded by disk rather than
by record count - the previous implementation loaded every record into memory
and would run out of it at full history size. Import is the mirror
(`INSERT OR REPLACE ... SELECT`) and is idempotent because rows match on their
canonical primary key. A `health_backup_meta` table carries the tool id and
schema version so a foreign file is rejected. Import checkpoints are excluded
deliberately: restoring them would claim data was imported on a device that
never read it.

The whole-app database export is separate and unaffected.

## Import Rules

Import all selected historical data. Do not import sessions only.

- Containers: sleep and exercise sessions plus their stages/laps/events.
- Continuous/single values: heart rate, HRV, SpO2, respiratory rate, weight,
  body fat, speed, cadence and similar points. These must be available in UI
  outside a session, for example HR over time.
- Intervals: steps, distance, calories, activity intensity and similar ranges.
- Session detail queries use the same continuous/interval rows by time range;
  sessions do not own copied metric data.

The importer must read one Health Connect page, write its records and
checkpoint in one SQLite transaction, then continue. An interrupted import
resumes the unfinished page token. A completed type is re-read on normal sync
from the last successful import window with a one-day overlap.

## Source and Duplicate Policy

Never delete raw source evidence because it resembles another source.

1. Preserve source records from every writer, including our own treadmill data.
2. Create duplicate candidates only for strong same-metric/same-range matches.
3. On a confirmed mirror the earlier-written record wins; the later one is
   marked `effective = 0` with `replaced_by_source_record_id` set.
4. A demoted record stays as source evidence and as fallback for a device that
   never saw the original.
5. Do not sum source mirrors in charts, totals, workout details, or daily
   aggregates.
6. **Never merge measurements on device metadata.** A user may own two physical
   scales that Health Connect cannot tell apart — they can even present the same
   device id. Only an exact `(metric_type, time, value)` collision may collapse
   such measurements.
7. Cross-device same original record id is one logical source record. It must
   not appear twice after Phone and Tablet sync.

Do not rely only on the generic +/- 5 second interval candidate logic. Session
matching additionally uses original ids, the client-id token rule above, range
equality/overlap and session type.

### Why blanket-filtering a republisher is wrong

A republishing app is not merely a mirror: it can be the only writer holding
data for a device that never saw the original, and it can carry data that
originated somewhere with no other local writer. In the captured data the Tablet
is a full republished copy for dense metrics — 274,188/274,188 heart-rate rows
and 2000/2000 sampled speed rows match the Phone exactly — yet it is still the
only source of 104 weight and 104 body-fat rows. Deduplicate; never exclude a
source wholesale.

## Sync Design

Backend remains generic. Do not create a Health-specific backend API or Health
backend tables.

Canonical entities are normal generic sync records with stable IDs:

```text
source2:...
record2:...
session2:...
detail2:...
sample2:...
interval2:...
candidate2:...
```

The trailing digit is `_idGeneration`. Bump it whenever canonical identity
changes; ids of another generation resolve to no table and are dropped on pull.

Generic backend changes are additive:

- Existing `/api/sync/:toolId` behavior works unchanged when clients omit new
  query parameters.
- Metadata supports bounded pages with `limit` and cursors.
- Pull/push have record and request-size limits.
- Flutter generic sync sends pull and push work in bounded batches.

Do not sync dashboard UI caches or `health_import_checkpoints`.


## Current Code State

Implemented:

- Schema migrations through version 9.
- Canonical identity is device-independent: `source` is keyed on the writer
  package, `source_record` on `package|original_record_id|type`. Ids carry a
  generation (`_idGeneration`, currently `2`).
- Metric samples are keyed on `(metric_type, time, value)`, so the same physical
  measurement re-read on another device collapses instead of duplicating.
- v9 rebuilds the canonical tables and clears import checkpoints, the sync
  cursors, and the Health Connect import watermark
  (`health_connect_last_sync`). All three live in settings, not in tool tables.
- The dashboard reads canonical `health_source_records` (filtered to
  `deleted = 0 AND effective = 1`) projected into the existing record shape via
  `_canonicalSelect`, so a device with no Health Connect renders everything it
  received over sync.
- Health Connect paging follows `response.nextPageRequest`.
- Canonical entities use generic sync delegate/records, with targeted id lookups
  rather than full-table scans.
- Duplicate detection is vendor-neutral: no writer package appears in any rule.
- The legacy `records` table is dropped; only its migration DDL survives.
- Tool backup/import is an in-SQLite table copy scoped to this tool's tables.
- Health Connect settings are one entry opening `HealthConnectSettingsPage`.
  The analysis and discovery exporters now have entry points there.
- Long imports hold a **partial (CPU) wake lock plus a foreground
  notification**, so the screen may sleep while the import continues.
- Actions attempted while an import or sync holds the tool show
  `HealthBusyDialog` instead of silently returning.
- Opening the tool paints stored records before any Health Connect or network
  work.

## Known Architecture Problem: the same data is stored twice

**This is the most important thing to understand before changing anything.**

`payload_json` on `health_source_records` is `jsonEncode(record.value)` - the
Health Connect record value stored verbatim, *including its `samples` array*.
`_upsertCanonicalSamples` then writes those same samples again as rows in
`health_metric_samples`. The dense data is stored twice, in two shapes.

Worse, only one of the two is ever read:

- **`payload_json` is the de facto source of truth.** Every dashboard query,
  aggregate and drilldown goes through `_canonicalSelect`, which maps
  `r.payload_json AS value_json`. Aggregates use `json_extract` on it.
- **The normalized child tables are write-only.** `health_sessions`,
  `health_session_details`, `health_metric_samples` and
  `health_interval_metrics` appear only in CREATE, INSERT, DROP, the sync and
  backup table lists, and the purge DELETEs. Grep for a SELECT against any of
  them: there is none.

How it happened: the normalized tables came from the earlier canonical rework.
When the "sync writes canonical, UI reads legacy" bug was fixed, the read
projection was pointed at `health_source_records.payload_json` because that was
the smallest change that worked. That left the child tables stranded.

Consequences, all currently live:

- Imports write every dense sample twice.
- Aggregates parse large JSON blobs instead of reading indexed numeric columns.
- Sync volume is roughly double what the data requires.

`health_interval_metrics` also cannot serve the aggregates as currently
written: `_upsertCanonicalInterval` emits **one row per record**
(`metric_type = record.type`, `value = _primaryValue(record)`), while
`allTimeWorkoutSummary` needs distance, calories and duration off a single
workout. The schema allows several rows per record
(`UNIQUE(source_record_id, metric_type)`); the writer just does not emit them.

## Import Path

`HealthConnectCollector.importCanonical` is the only live import path.
`HealthConnectCollector.collect()` and `_safeReadRecords` are dead code and
still contain the broken paging pattern described below - do not copy from
them.

Paging must follow `response.nextPageRequest`. `health_connector 3.9.x` exposes
**no** page token on the read response. A previous version read a page token
off the response through `dynamic`, which threw `NoSuchMethodError` *before*
the first page was written. The per-type catch swallowed it, so a full-history
import finished in seconds, reported success, and stored nothing. If an import
ever completes suspiciously fast, check this first.

Because page requests are opaque objects they cannot be persisted, so an
interrupted type resumes from its range start rather than mid-page. Canonical
upserts make that idempotent.

An import where **every** type failed now throws instead of reporting success
with zero records. Partial failures are still per-type log lines only.

## Measured Performance

Measured on the phone, full history, roughly 3M records:

- **13 seconds per 5,000 records, and the rate stays constant** as the tables
  grow. Constant rate is the check that matters: a decaying rate means
  something is scanning.
- At that rate a ~3M record import takes on the order of two hours.

Four fixes got it there, all of which must stay:

- Duplicate detection used an `ABS(start_time - ?) <= 5000` filter, which no
  index can answer. SQLite matched `type_id` then scanned every record sharing
  it, per record - quadratic. It is a sargable `BETWEEN` range now and uses
  `idx_source_records_type_time`.
- Dense series skip duplicate detection entirely. Their measurements already
  collapse on `(metric_type, time, value)`, so pairing carrier records off
  against every other record of the same type found nothing and cost the most.
- Samples are written in one batched commit per record. One `db.insert` per
  sample means one platform-channel round trip per sample.
- `health_sources` no longer has `updated_at` touched per record. Its contents
  do not change between records of the same package.

## Backend

Repository: `C:\dev\node\browser-toolkit`, deployed at
`https://tools.prox.obto.de`, running from `/opt/browserkit/backend`
(data at `/opt/browserkit/backend/data/sync.sqlite`). Backend commit `8706f5a`
is deployed and verified live.

Backend remains generic. Do not create a Health-specific backend API or Health
backend tables.

- Metadata supports bounded pages via a `limit` query parameter. Full scans use
  a keyset cursor `full:<snapshot>:<recordId>`; incremental scans use the
  change revision. Full scans pin a snapshot revision so records written
  mid-scan are picked up by the next incremental pass.
- Push/pull validate shape and are bounded by record count and payload size.
  `SYNC_MAX_REQUEST_BYTES` defaults to 32 MiB - it is an abuse guard, not a
  size clients aim for. Chiptune, signatures and sketch board push base64 blobs
  through the same route, and a 1 MiB cap rejects a single ordinary sketch.
- The change log prunes every `SYNC_CHANGES_PRUNE_INTERVAL` inserts rather than
  on every upsert, which previously walked the whole retained log per record.
  `SYNC_MAX_CHANGES_PER_TOOL` defaults to 1,000,000.
- The Flutter client streams: push payloads are read one batch at a time and
  batches cap on encoded size as well as count; pulled records apply per batch.

Server-side health-dashboard data was purged once on 2026-08-09
(`sync_data` 74,833, `sync_binary` 0, `sync_changes` 100,000) after the
generation-2 identity change. Purge is optional, not a prerequisite -
old-generation ids are dropped on pull.

### Sync will not survive this data volume as-is

`canonicalSyncRecords()` runs a query over **all seven tables with no limit**
and builds a Dart map per row. On a full sync - which is what an empty server
produces - that materializes every canonical row in memory before a byte moves.
At 3M rows this is expected to OOM on a phone. **This must be fixed before a
full sync is attempted at this scale.** Streaming push payloads, which is
already done, does not help here.

Do not sync dashboard UI caches or `health_import_checkpoints`.

## Operating It

A v9 upgrade leaves the dashboard empty until a full import runs - that is
expected, not a failure.

**Cloud sync can stay on.** Devices may upgrade at different times. Two
mechanisms make a mixed fleet safe without manual coordination:

- Canonical ids carry a generation. Entities from the previous scheme resolve
  to no table and are ignored on pull.
- A canonical rebuild clears sync cursors and the import watermark.

**Which import entry to use.** "Health Connect jetzt importieren"
(`connectHealthConnect`) resumes from `health_connect_last_sync` minus a day.
"Health-Connect-Import neu starten" (`repairHealthConnectCache`) purges local
Health Connect data and re-imports from 1970. After anything that leaves the
watermark stamped but the tables empty, use **neu starten**.

The restart purge is scoped to `source_kind = 'healthConnect'`. Treadmill
records are excluded deliberately: only Health Connect is re-imported
afterwards, so purging them would lose data nothing in that flow restores.

**When sync happens.** Never during an import. `repairHealthConnectCache` and
`syncHealthConnect` contain no backend call at all (`syncHealthConnect` is an
import, not a sync - the name is misleading). Backend push happens only in
`refreshOnOpen` (tool open, after any import in that pass) and the manual
Sync Now. `refreshOnOpen` returns early while `isCollecting`, so opening the
tool mid-import does nothing.

**Parallel devices.** Phone and tablet may import simultaneously; the imports
are independent and mixed builds are safe as long as `_idGeneration` and the id
inputs are unchanged. Avoid syncing both at the same moment: the HTTP timeout
is 10s per request and a large sync is thousands of requests against one SQLite
backend. A tripped timeout does not corrupt - the exception fires before the
cursor is saved - but the work is redone.

Sanity checks after a second device joins: workout count must not roughly
double, and heart-rate point counts must not jump about 2x. Either would mean
the dedup rules are not firing.

## Planned Work

Ordered. Steps 1-3 make the dashboard fast and need **no re-import** - every
number they require is already in `payload_json` on-device, so the backfill
reads the local database, not Health Connect.

1. **`_upsertCanonicalInterval` emits one row per numeric metric** rather than
   only the primary value - distance, calories, duration, steps.
2. **Backfill those rows from existing `payload_json`** in one pass over
   `health_source_records`. Re-runnable, minutes not hours.
3. **Point the aggregates at `health_interval_metrics`** - indexed
   `(metric_type, start_time)` with a real numeric column, replacing
   `json_extract` over blobs. This is the fast dashboard.
4. **Then** `payload_json` can drop its samples array, or disappear entirely.
   Only safe once 3 is proven, because it is currently the read source.
5. **Fix `canonicalSyncRecords()` to page** instead of materializing. Required
   regardless of the above; it is the crash risk.

### Sync redesign (separate piece of work)

Health Connect itself is the reference: it is a typed relational store, not
blobs, and it has no row-level cloud sync at all - its device-to-device story
is Backup & restore, which ships the whole SQLite file. A decade of history is
~20 MB that way.

Two shapes worth combining:

- **Seed by file.** Upload the existing per-tool backup (table copy) as one
  blob; a new device restores it in one shot instead of pulling millions of
  records over thousands of requests. **Caveat: this artifact grows without
  bound** - it is the entire tool database. It needs a size ceiling, a
  compression step, or a time-windowed variant before it can be relied on, and
  a device on a metered connection should not fetch it blindly. Pair it with a
  cutoff so the file seeds history up to a date and blocks carry the rest.
- **Delta by block.** One sync record per `(metric_type, day)` carrying that
  day's samples instead of one per sample. A decade of 41 types is tens of
  thousands of blocks rather than millions of rows. Past days never change, so
  coarse last-writer-wins is acceptable - the usual objection to blocking does
  not apply to append-only history.

Blocking also removes the `canonicalSyncRecords()` memory problem for free.

## Open Decisions

- Whether the open-time backend sync in `refreshOnOpen` should be gated by a
  setting. It currently runs on every tool open whenever cloud sync is enabled,
  independent of the "auto Health Connect sync" switch, which only gates the
  Health Connect import.
- Whether dense samples should sync to desktop at all. Excluding them means
  desktop gets every chart and aggregate but no intra-workout heart-rate
  curves, and sync stays small.
- `exportHealthConnectComparison()` in `health_dashboard_state.dart` and
  `exportComparison` in the exporter are dead - no caller, no UI. They served
  the phone-vs-tablet analysis above. Wire or delete.

## Status / Not Yet Verified

- The full-history import has been run on the phone and is progressing at a
  constant rate. It had not completed at the time of writing.
- A full backend sync at this data volume has **never** been run and is
  expected to fail on memory - see the sync warning above.
- Cross-device dedup has not been observed with two devices actually populated.
  The workout-count and heart-rate-count checks above are the test.
- The v9 migration, full re-import and backup table-copy path have not all been
  exercised end to end on hardware.

## Verification

Do not run release/production builds unless asked.

For Dart/source changes:

```text
dart format ./lib
flutter analyze
```

After editing ARB files:

```text
flutter gen-l10n
```

For browser-toolkit backend changes:

```text
bun x prettier --write backend/routes/sync.ts backend/lib/sync-db.ts
bun x tsc -p backend/tsconfig.json
```

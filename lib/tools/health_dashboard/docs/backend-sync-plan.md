# Health dashboard — backend sync plan

Status: **design, not implemented.** `config.dart` deliberately declares no
`syncDelegateFactory`. This document is the plan for putting one back.

Read `storage-model.html` first — this builds directly on the table layout
described there.

## Why it is worth doing

Three things the current device-local store cannot do:

- **Combined view.** Weight recorded on the phone is invisible on the tablet.
  Health Connect is device-local and does not sync, so nothing merges the two
  halves of one person's data.
- **Backup.** Lose the phone and the imported history goes with it. Health
  Connect's own backup is not something the dashboard can rely on.
- **Restore.** A fresh install should be able to reach a full dashboard without
  re-importing years out of Health Connect, which it cannot do for data the new
  device never held.

## Why the existing sync engine cannot carry it unchanged

`SyncService` is row-per-record: the metadata phase enumerates every record id,
and pull/push carry one record each. `health_point` is millions of rows. The
engine is fine; the granularity is wrong. Everything below is about choosing a
coarser unit that still lands in the existing protocol.

## The unit of sync: one (day, writer-app) chunk

```
id        = "d<epochDay>:<app package>"
updatedAt = when this device last imported rows into that (day, app)
data      = every point / interval / session that app wrote on that day
deleted   = the writer was deselected, or the day was cleared
```

Keying on the **writer app** is what makes the merge correct. A given app's
readings for a given day are the same data no matter which device imported
them, so:

- Two devices importing *different* writers for the same day produce different
  chunks. Both survive; the merged view is their union. This is the
  weight-only-on-the-phone case, and it works by construction.
- Two devices importing the *same* writer for the same day produce identical
  content. Last-writer-wins is a no-op rather than a clobber.
- Deselecting a writer tombstones every chunk carrying it — which is already
  how `health_type_app` thinks about writers.

Keying on the **device** instead would rebuild the failure this store was
designed to avoid: the same measurement under two device ids, counted twice.
Provenance can be carried as a display field, but it must never enter a chunk
id, a row primary key, or a rollup group-by.

## What makes a re-pull harmless

The chunk is only an envelope. Idempotence comes from primary keys that already
exist:

| table | primary key | on re-pull |
| --- | --- | --- |
| `health_point` | `(metric, t, v)` | identical rows collapse |
| `health_interval` | `(metric, t0, t1, v)` | identical rows collapse |
| `health_session` | `origin` UNIQUE | **inserts a duplicate — see below** |
| `health_daily` | — | never synced, recomputed locally |

Applying a chunk is `INSERT OR IGNORE` of its rows, then marking the touched
days dirty so the rollups rebuild. `health_daily` stays out of the protocol for
the same reason it is out of `backupTables`: its `day` is local midnight of
whichever machine computed it.

## The one real schema change: session identity

`health_session.origin` holds the Health Connect record id, which is a
**per-device** value. The same logical workout carries a different one on each
device, so a pulled session inserts as a second copy. This is the only place a
genuine duplicate appears.

Schema v3:

- add `dedupe_key TEXT`, backfilled as `client_id` when present, otherwise a
  hash of `kind | t0 | t1 | app`
- unique index on `dedupe_key`
- `origin` keeps its column but loses `UNIQUE` (table rebuild)

`client_id` already exists and is already populated from
`metadata.clientRecordId` in `health_connect_mapper.dart`, so every treadmill
workout — written as `toollab:treadmill-control:<uid>:<part>` — dedupes across
devices for free. Only third-party sessions fall back to the content hash.

## Dimension tables: send strings, never ids

`health_metric`, `health_app` and `health_text` intern to integers assigned
locally. One device's `app=3` is another's `app=7`. The chunk payload carries
plain strings — package name, activity name, metric key — and the receiver
re-interns through the normal import path. The dimension tables never enter the
protocol, so their ids cannot collide.

## A manifest table so the metadata phase stays cheap

`getLocalSyncRecords()` must never scan `health_point`.

```sql
CREATE TABLE health_chunk (
  day        INTEGER NOT NULL,
  app        INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  dirty      INTEGER NOT NULL DEFAULT 1,
  deleted    INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, app)
) WITHOUT ROWID
```

The importer bumps `(day, app)` whenever rows land for it. The delegate maps
straight onto the engine's existing shape: `getLocalSyncRecords` reads this
table, `getLocalPendingSyncRecords` is `WHERE dirty = 1`, and
`finalizeLocalSync` clears `dirty`.

## Volume

Roughly three writers over 365 days is about 1.1k chunks a year, so a decade is
~11k — around 22 metadata pages at the engine's existing batch size, and only on
the first run, since the cursor path makes later runs delta-only.

Payload is the part that needs care. A day of dense samples as plain JSON is
tens of KB, which puts a decade in the hundreds of MB. Pack each metric's day
series instead — delta-encoded times, scaled integer values — and ship it
through the `__type: 'blob'` wire format the backend already stores as a real
`BLOB` and `SyncService._unwrapBlobData` already unwraps centrally. That is an
order of magnitude smaller. History depth should also be a user setting; not
everyone wants a decade mirrored.

## Restore

Falls out of the above: fresh install, pull every chunk, re-intern the
dimensions, rebuild `health_daily` from local midnight. No Health Connect
involvement, which is the point — the new device never held that history.

## Deliberate non-goals

- **Single-sample deletion does not propagate.** Only whole chunks tombstone.
  Deleting one reading in Health Connect is picked up by re-importing that day,
  which rewrites the chunk. Anything finer would need per-row tombstones, which
  is a cost out of all proportion to the case.
- **`health_daily` is never transmitted.** It is derived, and its key depends on
  the reader's timezone.
- **No device identifier participates in any key.** It may be stored for display
  or debugging only.

## Build order

1. ~~Distance delete workaround in the treadmill publisher.~~ Done — independent
   of sync, closes the wipe gap.
2. Schema v3: `dedupe_key` and `health_chunk`, with the importer maintaining
   both. No network, no visible behaviour change; verifiable on its own.
3. `HealthSyncDelegate` with plain JSON payloads. Correctness first.
4. Swap point and interval payloads to packed blobs once step 3 is proven.
5. Register `syncDelegateFactory` in `config.dart`, drop the comment explaining
   its absence, and fold the storage consequences into `storage-model.html`.

Steps 2 and 3 are the bulk of the work.

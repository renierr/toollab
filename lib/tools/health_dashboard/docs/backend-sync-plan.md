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
- Deselecting a writer is a per-device filter, not a data assertion, so it stops
  the import, filters the view, stops the pull — and leaves the chunk alone.
  Hiding a writer on the tablet must not delete the phone's data. Tombstones are
  reserved for the explicit delete actions.

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
| `health_session` | surrogate `id` | **inserts a duplicate — see below** |
| `health_daily` | — | never synced, recomputed locally |

Applying a chunk is `INSERT OR IGNORE` of its rows, then marking the touched
days dirty so the rollups rebuild. `health_daily` stays out of the protocol for
the same reason it is out of `backupTables`: its `day` is local midnight of
whichever machine computed it.

## The chunk is read from SQLite, never from the import batch

`getLocalRecordData` reads the whole `(day, app)` set out of the local tables —
Health-Connect-imported rows and backend-pulled rows together. It must never
serialize just what an import run happened to produce.

That single rule is what makes the interesting cases work:

- **Re-import.** Health Connect hands back rows that already exist; the content
  primary keys collapse them; the chunk is unchanged. Re-importing costs nothing
  and loses nothing.
- **Partial overlap inside one writer.** One device holds weight for a day and
  the other holds steps, both under the same package, so both are the same chunk
  id. Because each device serializes everything it knows — including what it
  pulled — the second push is a superset of the first and the server record only
  grows. Serializing the import batch instead would let the thinner device
  clobber the fuller one on the server; local rows would survive but a restore
  would get the thin copy.
- **Different writers.** Different package, different chunk id, different server
  record. They never compete; the merged view is their union.

Two corollaries:

- Only bump `health_chunk.updated_at` when rows were actually **added**. An
  import that inserts nothing must leave the chunk clean, or every run re-uploads
  a full day and the other device pulls it straight back.
- When applying a pulled chunk inserts rows the sender did not have, mark that
  chunk dirty. It was not in the push set — the server looked newer at metadata
  time — so without this the local superset never travels back. With it, the two
  devices converge on the following run.

## The one real schema change: session identity

Every other fact table is keyed on its own content, so a pulled row that is
already present simply collapses. `health_session` cannot be: `health_session_part`
hangs off its surrogate `id`, and the summary columns are not identity. Its only
uniqueness rule was `origin UNIQUE`, and `origin` is the Health Connect record
id — assigned by the Health Connect instance that stored the row.

That id is **mostly, not reliably** shared across devices. The captured
phone/tablet comparison in `README.md` puts it at 624/626 for exercise sessions
and 152/167 for sleep. A rule that is right 96% of the time is a fine hint and a
bad primary key, and it is also `NOT NULL`, which a row that only ever arrived
through a chunk has nothing to satisfy.

Schema v3:

- add `dedupe_key TEXT`, unique: `c:<client_id>` where the writer set one,
  otherwise `k:<kind>|<t0>|<t1>|<package>`
- `origin` keeps its column but loses `UNIQUE` and `NOT NULL` (table rebuild),
  and gains a plain index — `deleteSessionsByOrigin` was relying on the implicit
  one the constraint provided
- the import path matches on `dedupe_key` first and falls back to `origin`, so
  a writer that edits a workout's bounds still updates its row rather than
  adding one

A plain composite rather than a hash: it is device-independent either way, and
readable in a debug dump. `client_id` already exists and is already populated
from `metadata.clientRecordId` in `health_connect_mapper.dart`, so every
treadmill workout — written as `toollab:treadmill-control:<uid>:<part>` —
dedupes across devices for free, including when the same workout arrives once
through the treadmill tool's own sync and once inside a health chunk.

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

`day` is a **UTC** epoch day, deliberately unlike `health_daily`, which keys on
local midnight. A chunk is a sync partition rather than something the user reads,
and two devices in different timezones have to cut the same rows the same way.

The importer bumps `(day, app)` whenever rows land for it. The delegate maps
straight onto the engine's existing shape: `getLocalSyncRecords` reads this
table, `getLocalPendingSyncRecords` is `WHERE dirty = 1`, and
`finalizeLocalSync` clears `dirty`.

"Whenever rows land" has to mean rows that were actually inserted, and sqflite
cannot report that: `INSERT OR IGNORE` into a `WITHOUT ROWID` table leaves
`last_insert_rowid()` untouched, so an ignored insert is indistinguishable from a
real one. `writeRecords` therefore batches per chunk instead of per page and
reads SQLite's `total_changes()` either side of each commit. Sessions are
counted separately: `_writeSession` compares against the stored row and returns
whether anything moved, because an UPDATE writing identical values still counts
as a change.

## Everything this adds to the schema

The whole storage cost of sync is one table, one column, and one settings row.
No other table changes, and no existing table gains a device column.

**New table — `health_chunk`**, the manifest above. `day` is the epoch day,
`app` the interned writer id, both already what the fact tables key on.
`WITHOUT ROWID`, so it stays as small as the two integers it holds. At three
writers over a decade this is ~11k rows.

**New column — `health_session.dedupe_key TEXT`**, unique, with `origin` losing
its own `UNIQUE` and `NOT NULL` (a table rebuild). See the section above for what
it holds and why the Health Connect record id cannot serve.

**Cursor storage — no table.** `getSyncCursor` / `saveSyncCursor` go through
`DatabaseService.setSetting(<tool id>, 'sync_cursor_<syncId>', …)`, keyed by
`syncId` because the engine namespaces it per user. Health dashboard is the first
delegate to implement these at all; every existing tool inherits the
`DefaultSyncDelegate` no-ops and re-reads full metadata each run.

**Unchanged and deliberately so.** `health_metric`, `health_app` and
`health_text` intern to locally assigned integers and never enter the protocol —
payloads carry plain strings and the receiver re-interns. `health_daily` is
derived and never transmitted. `health_type` and `health_type_app` hold Health
Connect *read progress* (`history_done`, `range_start`/`range_end`, `last_t`),
which is per-device by definition and must not sync.

That last point is worth stating plainly, because the two marker sets are easy
to conflate: `health_type*` answers "how far have I read out of Health Connect on
this device", `health_chunk` plus the cursor answers "what have I shipped to the
backend". Resetting one has no bearing on the other.

## Sync order

Backend pull first, Health Connect second, backend push last. Pulling first means
the chunk is computed over a table that already holds the other device's rows, so
the push is a true superset; pushing first would ship a chunk missing everything
the other device knows.

The engine already gives this ordering for free. `SyncService.sync` runs its pull
phase before its push phase, and `_pushBatches` materializes payloads lazily
*during* the push phase — so `getLocalRecordData` is called after pulled rows have
landed. The caller only has to order its own two steps:

```
importIntoStore()   // Health Connect → local tables
SyncService.sync()  // pull merges in, then push ships the union
```

A fresh install skips the first step entirely: pull everything, re-intern the
dimensions, rebuild `health_daily` from local midnight. That is the restore path,
and it needs no Health Connect involvement — which is the point, since the new
device never held that history.

## The destructive actions

Three existing actions delete rows. None of them is ambiguous today, because
nothing syncs. All three become ambiguous the moment a delegate exists, and each
needs a decided answer.

**`clearImportedData()` — "remove everything and re-import".** Wipes every table
in `dataTables` and resets the Health Connect progress markers, then
`importIntoStore(restart: true)` reads history back from scratch. Under sync this
is the dangerous one: the wipe also removes rows that came from the *backend*,
and the re-import only recovers what *this* device's Health Connect still holds,
which is generally less.

It must not be treated as a deletion. It is a **local rebuild**, and the fix is to
extend the wipe rather than restrict it: clear `health_chunk` as well, and clear
the stored cursor. Then the local manifest is empty, so the next run has nothing
to push and pulls every server chunk back; the Health Connect re-import adds this
device's share on top; the following push ships the union. Nothing shrinks on the
server at any point, and the action becomes self-healing — it is in fact the
cleanest way to repair a device whose local state has drifted.

**`deleteApp(package)` — "reclaim the space this writer costs".** Deletes by
interned `app` id, which also catches that writer's rows pulled from other
devices. Two intents hide behind one button, so the confirm dialog asks which:

- *Free space on this device* drops the rows and the writer's manifest rows.
  Nothing is tombstoned, so another device's copy is untouched. The default,
  because it is the reversible one.
- *Remove from every device* keeps the chunks and marks them `deleted`, so the
  deletion travels. The one case where a chunk is allowed to shrink.

The choice is only offered while the tool actually syncs — server configured, a
delegate registered, the per-tool switch on. Without a backend there is one copy
and nothing to decide.

**No pull-exclusion list.** The plan originally wanted one, so a local delete
would not be undone by the next pull. It is unnecessary: the delegate declines
chunks whose writer is switched off here, which is already what the writer switch
means everywhere else — off is neither imported nor counted. So a local delete
sticks exactly when the writer is switched off, and comes back when it is not,
which is the same rule that already governs re-importing from Health Connect. One
concept instead of two.

A declined chunk still gets a manifest row, marked `skipped` and stamped with the
server's own `updated_at`. Without it the engine would see no local record and
re-pull the same chunks on every run; with it the chunk looks settled and is
never a push candidate, because it is not dirty and its stamp does not exceed the
server's. Re-admitting the writer deletes those rows, so the history arrives.

**`pruneUnused()`** is local-only and needs no choice at all: it touches nothing
but globally switched-off writers, and those are not pulled.

`VACUUM` is orthogonal — it rewrites the file so freed pages return to the
filesystem. It carries no sync meaning and needs no handling here.

## Volume

Roughly three writers over 365 days is about 1.1k chunks a year, so a decade is
~11k — around 22 metadata pages at the engine's existing batch size, and only on
the first run, since the cursor path makes later runs delta-only.

Payload is the part that needs care. A reading as JSON is about 39 bytes —
`["heart_rate",1778803200000,61,null]` — and nearly all of it is the repeated
metric name and a thirteen-digit timestamp. Grouped by metric, delta-encoded and
varint-packed, the same reading is around four, and it ships through the
`__type: 'blob'` wire format the backend already stores as a real `BLOB` and
`SyncService._unwrapBlobData` already unwraps centrally.

Measured over 129 real chunks (12,126 points, 1,947 intervals): 597 KB of dense
JSON becomes 141 KB on the wire and 105 KB at rest, a factor of 4.2. Denser days
do better — the per-metric header is a fixed cost, so a full heart-rate series
day approaches 7x.

**Values have to round-trip bit-for-bit.** `health_point` is keyed on
`(metric, t, v)`, so a value returning as 10.554 instead of 10.553866523510644
is not a rounding error, it is a different primary key, and the receiver inserts
a second row beside the first — on every device that pulls it. Each metric
therefore picks the smallest decimal scale that reproduces all of its values
exactly and falls back to a full float64 when none does. Paired readings stay in
the plain JSON list: only blood pressure carries a `v2`, there are a handful, and
keeping them out costs less than a second optional series in the format.

The first byte is a format version. A blob from a newer build **throws** rather
than decoding to nothing: skipping the rows would settle the chunk as though it
had been applied, and those readings would never arrive again. Failing leaves the
chunk unsettled, so updating the app is enough to pick it up. A blob that is
merely corrupt at a known version is dropped instead — nothing will repair it,
and retrying forever is worse than losing it.

Receivers read both forms, so chunks written before packing existed still pull.

History depth should also be a user setting; not everyone wants a decade
mirrored.

## A per-tool sync switch

One global `sync_enabled` is too blunt once this tool participates. Notes are a
few kilobytes; a decade of samples is not, and a user who wants their notes on
two devices has not thereby asked for that.

The switch is per tool, and the global one becomes the master:

- **Global stays as it is** — off means nothing syncs, and it owns the server URL
  and user id.
- **Per tool**, stored the way `pinned_shortcut` already is:
  `DatabaseService.setSetting(tool.id, 'sync_enabled', …)`. No new table, no new
  service.
- **Default on**, for every tool that already syncs today. The switch must not
  silently turn off an existing tool's sync on upgrade, so a missing value reads
  as enabled.
- **`sync_settings_page.dart` grows a section** listing
  `ToolRegistry.all.where((t) => t.syncDelegateFactory != null)`, one switch each.
  Self-maintaining — a new sync-capable tool appears without editing the page.
- **"Sync Now" and any background run skip disabled tools.** Registration in
  `AppState` stays eager so the list can render regardless.

Two behaviours to get right:

- Turning a tool off must not purge its server data. It stops participating,
  nothing more.
- Turning it back on must clear that tool's cursor, so the next run does a full
  metadata pass. Tombstones written while it was off are already behind the
  cursor and would otherwise never be seen.

Health dashboard gets a history-depth setting alongside its switch — how many
years to mirror. Everyone can afford to sync notes; not everyone wants a decade
of samples.

## What applying a pulled chunk does to the manifest

The merge itself is `INSERT OR IGNORE` through the normal import path, so the
content primary keys collapse what is already stored and `dedupe_key` catches the
one table that cannot. What the chunk's own manifest row becomes afterwards is
the part that decides whether the two devices converge:

- **The chunk was already dirty.** This device holds rows the sender did not, and
  it was not a push candidate — the server looked newer at metadata time — so
  nothing else would ever carry them back. It stays dirty and takes a stamp above
  the server's, and the next run pushes the union.
- **The chunk was clean.** Everything it held had already been pushed, so the
  sender's copy is a superset of it and the two sides now agree. It adopts the
  server's stamp and settles.

Marking a clean chunk dirty instead is the tempting simplification and it does not
terminate: each device would see the other's stamp as newer, mark its own copy
dirty, and push it back forever.

The stamp for the dirty case is `max(now, serverUpdatedAt + 1)` rather than `now`,
because a device whose clock trails the sender's would otherwise write something
the engine reads as older and re-pull the same chunk on every run.

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
2. ~~Per-tool sync switch, defaulting on.~~ Done — `AppState.syncWithBackend` is
   the single gate, the switch list is registry-driven, and re-enabling a tool
   drops its cursor. Nothing below is reachable until a delegate exists.
3. ~~Schema v3: `dedupe_key` and `health_chunk`, with the importer maintaining
   both, and `clearImportedData` extended to clear the manifest and cursor.~~
   Done — the migration also rebuilds the manifest from existing rows, and a
   backup restore derives both, since a snapshot cannot know what a device has
   shipped.
4. ~~Decide the `deleteApp` / `pruneUnused` intent split in the UI.~~ Done — the
   confirm dialog offers the scope while the tool syncs, `everywhere` tombstones
   the writer's chunks, and the writer switch doubles as the pull filter, so no
   exclusion list exists.
5. ~~`HealthSyncDelegate` with plain JSON payloads, including a real cursor
   implementation, and skipping chunks whose writer is switched off.~~ Done —
   schema v4 carries the two indexes reading a chunk needs and the `skipped`
   marker, and the delegate is registered.
6. ~~Swap point and interval payloads to packed blobs once step 5 is proven.~~
   Done — `health_chunk_codec.dart`, measured at 4.2x on real data.
7. ~~Register `syncDelegateFactory` in `config.dart`, drop the comment explaining
   its absence, and fold the storage consequences into `storage-model.html`.~~
   Done — the delegate is registered, and `storage-model.html` carries the chunk
   table, the sync settings and the write paths that touch them.

Steps 3 and 5 are the bulk of the work.

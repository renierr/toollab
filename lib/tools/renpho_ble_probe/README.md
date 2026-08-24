# Renpho Scale

A complete local replacement for the official Renpho app for the MorphoScan Nova
(advertised as `RT-MSC04`, sold as `R-AMSC04`). It talks to the scale over BLE,
decodes the body-composition record itself, stores every reading in the tool's
own SQLite database, and optionally pushes the results to the sync backend and
to Health Connect. No Renpho cloud account is involved at any point.

## What it does

- Finds the scale by advertised name, remembers the one it paired with, and
  offers a manual picker for a relabelled unit.
- Walks the BLE setup handshake, then guides the measurement through its two
  halves — stand still, then grab the handles — with a step indicator driven off
  the scale's own state broadcasts.
- Decodes the full result: weight, BMI, body fat, muscle, visceral fat and ten
  segment impedances, plus the stored records the scale kept while offline.
- Derives everything else on read (see *Calculated values*), so a formula fix
  corrects the whole history rather than only later scans.
- Dashboard: live readout, metric grid with the week behind each figure, two
  seven-day trend charts (weight over body fat, muscle over body water) and the
  history in collapsible monthly blocks with per-scan details.
- Per-scan details show the segments as an interactive body map, and the toolbar
  exports a one-page PDF report (see *PDF report*).

## Files

| File | Role |
| --- | --- |
| `renpho_scale_protocol.dart` | Wire format only — framing, decoding, commands, fragment reassembly. No Flutter imports. |
| `renpho_ble_probe_state.dart` | Connection, setup state machine, packet dispatch, persistence, sync triggers. |
| `renpho_body_metrics.dart` | `RenphoDerived` — everything the app calculates from a stored measurement. |
| `renpho_measurement.dart` | The profile and the measurement record. Measured fields only. |
| `renpho_measurement_db.dart` | Namespaced SQLite table, migrations, dedupe, sync bookkeeping. |
| `renpho_sync_delegate.dart` | Backend sync, behind the app-wide sync switch. |
| `renpho_health_connect_publisher.dart` | Health Connect push, behind its own local switch. |
| `renpho_import.dart` | Reads a Renpho export into measurements. Pure parsing, no database. |
| `renpho_error_message.dart` | Maps `RenphoFailure` to localized text. |
| `renpho_body_geometry.dart` | The front-view figure in a normalised box: segment paths, callout rectangles, anchors, the value-to-colour rule. Drives the on-screen map and the printed one. |
| `renpho_body_image.dart` | Renders that figure off-screen to a PNG for the report. |
| `renpho_assessment.dart` | Rates a measurement against published reference ranges. Pure logic, no strings. |
| `renpho_report_pdf.dart` | Builds the one-page PDF. |
| `widgets/` | All presentation. Only the routed page uses `ToolLayout`; pushed sub-pages use a plain `Scaffold`, because `ToolBackButton` resolves a GoRouter state that a `MaterialPageRoute` does not have. |

## Protocol

### GATT layout

| Item | Value |
| --- | --- |
| Control service | `1A10` |
| App → scale | `2A11` (write) |
| Scale → app | `2A10` (notify) |
| Scale → app, extended | `2A12` (indicate) |
| Result transport | `0003`, outside the control service |

The `0003` characteristic matters: multi-part body-composition results arrive
there. Miss that subscription and the setup completes, the scale measures, and
no result ever reaches the app.

`2A12` must be subscribed as an **indication**. Subscribing it as a notification
leaves the CCCD in the wrong mode and the scale goes quiet.

### Frame format

```text
55 AA <type> <len:2 BE> <payload...> <checksum>
```

`len` counts payload bytes only. The checksum is the mod-256 sum of every
preceding byte including the `55 AA` prefix. All multibyte fields are
big-endian.

Long results are fragmented at the ATT layer with a `AD`/`AE`/`AF` prefix:
`AD <seq> <remaining> <data...>` opens, `AE` continues, `AF` with a zero
remaining count closes. `RenphoFragmentAssembler` reassembles them.

### Frames from the scale

| Type | Meaning |
| --- | --- |
| `0x20` | Free-running state broadcast, `<seq> <state> ...`. Not an acknowledgement. Observed states: `0x01` idle, `0x09` impedance phase started, `0x11` computing the result, `0x04`/`0x05` after the session. |
| `0x21` | Live weight while the user is settling. |
| `0x22`, `0x23` | Setup acknowledgements. |
| `0x24` | Settled weight, no body composition. |
| `0x25` | Live body-composition result. |
| `0x26` | Stored record from the scale's own memory, carrying an extra age field. |

Result records `24`, `25` and `26` share one layout at three levels of
completeness:

```text
55 AA <type> <len:2> <seq> <flags> [<age:4> only for 26] <weight:4>
      <nZ=0x0A> <10 x impedance:2> <calcFlag> <bodyfat:2> <bmi:2>
      <muscle:2> <visfat:2> <checksum>
```

- `weight` is `uint32 / 100`. A `24` ends after this field.
- `nZ` is the impedance count; it is `0x0A` in every observed record, but the
  decoder reads it rather than assuming it.
- Impedances are `uint16 / 10`, ordered 20 kHz trunk, left hand, right hand,
  left foot, right foot, then the same five at 100 kHz.
- `calcFlag` is `1` when the scale computed a body composition. When it is `0`
  the four trailing fields are zero and the frame is treated as a weight update,
  not a measurement.
- `bodyfat`, `bmi` and `muscle` are `uint16 / 10`; `visfat` is a plain `uint16`.

Reading `bodyfat` or the trunk impedances as single bytes appears to work and
then overflows above 25.5. Both are `uint16`.

`age` on a `26` record is the number of seconds between the measurement and its
transfer, so a stored record gets a real timestamp rather than the arrival time.

### Frames to the scale

| Command | Purpose |
| --- | --- |
| `B2` | Handshake. Carries the last weight the app knows about, and is re-sent after a result to close the session. |
| `B3` | Clock and timezone sync (unix seconds, then the local UTC offset in minutes). |
| `B8` | Request the stored records. |
| `B7` | Select the profile by name. Printable ASCII only, 16 characters. |
| `B6` | Acknowledge one stored record. |

### Setup sequence and why it is timer-driven

`B2` → `B3` → `B8` → `B7`, in that order, spaced out. Writing all four at once
makes the scale drop the profile and fall back to weight-only mode with its
"open the Renpho app" prompt.

The acknowledgement type is *usually* the command type minus `0x90`, so `B2` is
answered by `0x22`. Firmware revisions disagree about this, and the unprompted
`0x20` broadcast lands in the middle of the exchange, so the app does **not**
block on a specific frame. Each step advances when its expected acknowledgement
arrives, and otherwise after a short pause. Stalling is the worse failure: an
unfinished sequence means no body composition at all.

Two signals shorten the pacing, because they mean the user is already standing
on the scale and the remaining setup is now urgent:

- a `0x20` broadcast with state `0x09` (impedance phase started)
- a `0x24` settled weight

A watchdog covers the case the per-step timer cannot: a scale that answers
nothing at all gets one silent retry of the whole sequence before the scan is
reported as failed.

### Discovery and connecting

The scale advertises only for a few seconds after it is woken, and it stops
advertising entirely while something holds a link to it. Three consequences the
code has to handle:

- **A link left open hides the scale.** Windows keeps the GATT connection across
  app restarts, so the next scan finds nothing and the tool looks broken. A
  scan therefore drops any session it still holds, an idle session is closed
  after five minutes, and before scanning the tool asks the platform for already
  connected devices and reuses one that matches.
- **Stopping the scan before connecting breaks the connect.** The platform drops
  the freshly seen advertisement and answers with `Unreachable`. The scan stays
  up until the link is actually established.
- **One connect attempt is not enough.** Four attempts with a growing backoff,
  disconnecting in between so the next advertisement re-registers the device.

A scan that finds nothing within twenty seconds stops and says so rather than
spinning. The scale is matched by advertised name (`RT-MSC04`, `R-AMSC04`,
anything containing `MSC04`, `MORPHOSCAN` or `RENPHO`) or by having been paired
here before; no MAC address is baked in. The device sheet is the escape hatch
for a relabelled unit.

### Measurement phases

A measurement has two halves that ask different things of the user, so the UI
names them instead of showing one blanket status. The step is driven straight
off the wire:

| Step | Trigger | What the user is told |
| --- | --- | --- |
| Weight | a `0x21` live weight | stand barefoot on the scale, keep still |
| Handles | a `0x24` settled weight or `0x20` state `0x09` | grab both handles, arms straight, hold still |
| Result | `0x20` state `0x11` | calculating |
| Done | the `0x25` record is stored | complete and saved |

The step only ever moves forward within a session, so a stray live weight
arriving after the handles are gripped cannot drag the display backwards.

The screen is kept awake for the whole session — from pressing search, not from
the link coming up — and the lock is released when the measurement finishes, the
scan stops without connecting, or the tool is left.

### Session flow

1. Connect, request a large MTU, subscribe `2A10`, `2A12` and `0003`.
2. Run the setup sequence above.
3. If the scale holds unsynced measurements it pushes them as `26` records; each
   one is acknowledged with `B6` using the *fragment* sequence, not the sequence
   byte inside the reassembled packet.
4. The user steps on and holds both handles. Live weight arrives as `21`, the
   settled weight as `24`, then the extended `25` result.
5. The app stores the result, re-sends `B2` with the new weight and closes the
   link. Holding it open would keep the scale from advertising for the next
   scan, so a finished measurement always ends the session.

The acknowledgement pairing observed on this unit is `B2`→`0x22`, `B3`→`0x23`,
`B7`→`0x27`. `B8` is not acknowledged at all — the scale answers it by pushing
its stored records after `B7`, which is why the sequence must not block on it.

A completed setup does not imply a measurement will follow, and a `25` is not
proof of a *fresh* measurement — the scale can replay the previous record
unchanged. Insertion drops anything within thirty seconds of an existing row.

## Storage

The measurement table lives in the tool's namespaced database, keyed by tool id.
Only measured fields are persisted, together with a snapshot of the profile the
scan was taken under, so a later height correction does not silently rewrite old
results. Sync bookkeeping (`synced`, `deleted`, `created_at`, `updated_at`,
`health_connect_published_at`) rides on the same row, as does the provenance of
the reading: measured live, read out of the scale's memory, or imported.

## Importing an existing history

Tool settings → *Alte Daten importieren* reads a JSON export into the local
history. The parser is deliberately lenient, because the same data reaches
people in three different shapes: the raw cloud response, rows dumped out of a
helper script, and this tool's own sync payload. Every field is looked up under
all the spellings seen in those, and the record list is found whether the file
is a bare array or wrapped in `data`, `data.lists`, `measurements`, `records`,
`rows` or `items`.

Fields taken from a cloud record: `weight`, `bmi`, `bodyfat`, `muscle`
(skeletal muscle percent — *not* `sinewRatio`, which is itself derived),
`visfat`, the ten `z20*`/`z100*` impedances, `height`, `gender` (1 male,
0 female) and `measureAge` or `birthday`. `bodyage` is ignored on purpose: that
is the metabolic age the scale estimates, not the person's.

Two traps worth remembering:

- **`timeStamp` is not a real unix epoch.** Across a whole export it sits a
  fixed number of hours away from the `localCreatedAt` in the same record, so
  the local wall clock is used whenever both are present.
- **A record with no body composition is still kept.** Plain weigh-ins carry
  only a weight, and the weight trend is the series people look at most.

Insertion goes through the same thirty-second window that keeps the scale's
replayed records out, so re-importing a file changes nothing. Imported rows are
flagged as such and show a distinct icon and source in the history, because they
were neither measured live nor read out of the scale's memory.

### Reading the history

The history is grouped into one collapsible block per month, newest open and the
rest shut. Nothing about a closed month is in memory beyond its name and count:
the dashboard reads the newest two rows for the headline and its delta, one week
for the trend charts, and a list of bare timestamps for the month index. A
month's measurements are read when its block is opened and the least recently
opened months are dropped once a handful are cached.

The block bodies are built only while open. An `AnimatedCrossFade`-style
collapse would build every closed month's rows as well, which is exactly the
cost this avoids.

## Calculated values

`RenphoDerived` computes everything else on read, in three tiers that the
details page keeps visually separate:

1. **Exact** — arithmetic on the reported values: BMI, fat mass, fat-free mass,
   skeletal muscle mass.
2. **Renpho model** — fitted regressions matching the official app's output:
   body water, protein, bone mass, subcutaneous fat, BMR, body score, body type
   and the per-segment fat and muscle masses. These were fitted against one
   profile, so the details page shows an amber caveat when the current profile
   is outside that range, and the Health Connect export falls back to
   Katch-McArdle, which is measurement-driven and profile-independent.
3. **Published equations** — independent estimates from the literature
   (Mifflin-St Jeor, Katch-McArdle, Kushner-Schoeller, Sun, Janssen) at 100, 50
   and 20 kHz, shown for comparison.

## PDF report

The toolbar's PDF button builds one A4 page for the latest reading: the profile
and both timestamps, six key values, the segment figure with its callouts and
table, the assessment, and the two seven-day charts. The figure is the same
geometry as the on-screen map, rendered off-screen on a light background; the
charts are vector charts from the `pdf` package.

`renphoAssessment` rates seven values against population reference ranges — BMI
against the WHO classes, body fat against the ACE ranges by sex, the visceral
score against the scale's own 1-14 scale, body water and the skeletal muscle
index (EWGSOP2 cut-offs) by sex, the weakest segment against its standard, and
the left/right muscle difference. These are population averages behind a
consumer bioimpedance estimate, which is what the page's footer says; change the
ranges and the footer together.

## Sync and Health Connect

Backend sync goes through `RenphoSyncDelegate` and follows the app-wide switch
plus this tool's own sync switch, like every other tool. `backgroundSync()` fires
both halves on tool open, after a completed scan, and after a JSON import; the
toolbar button runs the backend half only. Health Connect is separate and **off
by default** — body composition is personal even by health-data standards. When
enabled it writes weight, body fat, lean mass, bone mass, body water and BMR,
each record tagged with a client id derived from the measurement uid so a
re-publish replaces rather than duplicates.

The push is deliberately resilient, because a scan that misses Health Connect is
otherwise lost until someone notices:

- Permissions are evaluated per type and treated as advisory. Health Connect
  can revoke a single type (the unused-app reset, a type the user unticked, a
  type the installed version does not carry); only the missing ones are
  re-requested and the granted ones are still written. The granted set is read
  back, but a read that fails is not read as "nothing granted" — then every type
  is attempted, since a write without permission fails only its own type.
- Records are written one type at a time. One rejected value cannot take the
  other five down with it.
- A scan is marked published only when every writable type went through, and the
  marker stores the `updated_at` that was written, so a failure or a concurrent
  edit leaves it pending. Re-publishing is an upsert on the client record id, so
  a retry never duplicates.
- The five-minute throttle is armed only by a clean run, and a failed run is
  retried on the next open.
- Publishing runs after a scan, on tool open, and on every backend sync — the
  sync path goes through `SyncDelegate.publishToHealthConnect()`, so it fires
  even when the tool itself takes no part in sync. The local Health Connect
  switch still decides.

## Profile

Sex, height and birth date never reach the scale; they only feed the
calculations. Nothing is guessed: a scan is blocked until the profile has been
filled in, because attributing a body composition to invented defaults produces
numbers that look real and are not.

## Keeping this current

This file is part of the tool. When the frame layout, the setup sequence, the
stored fields, the derived tiers, the report's reference ranges or the export
behaviour change, change this file in the same commit.

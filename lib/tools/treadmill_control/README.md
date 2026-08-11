# Treadmill Control — Health Connect publishing

Workouts are stored in the tool's own `workout_sessions` table and pushed **one way** into
Health Connect. Nothing is ever read back from there; the health dashboard is what reads
Health Connect, which is how treadmill workouts reach it.

## Record identity

Every record carries a client record id:

```
toollab:treadmill-control:<session uid>:<part>
```

`<part>` is one of `exercise`, `heart-rate`, `speed`, `distance`, `energy`, `steps`, and the
prefix comes from `TreadmillControlTool.config.id`. `clientRecordVersion` is the session's
`updated_at`.

Health Connect keys a record on **(writing package, client record id)**, so writing the same id
again replaces the record instead of adding one. The session uid is generated once and travels
with the backend sync, so a workout recorded on one phone and pulled onto another keeps the same
id — which is what stops two devices from producing two copies of one workout. The higher
`clientRecordVersion` wins, so the most recently edited version of a workout is the one that
survives.

Renaming a part string orphans every record already written under the old name.

## When it publishes

| Trigger | Throttled |
| --- | --- |
| A workout ends (`_backgroundSync`) | no |
| **Publish now** in the tool's settings sheet | no |
| Turning the Health Connect switch on | no |
| **Sync now** on the history screen | no |
| App-wide "Sync Now" in Settings | no |
| Health dashboard pull-to-refresh / refresh button | no |
| Opening the health dashboard | yes |

Everything the user asked for passes `force: true`; only the automatic open trigger is throttled,
and it is skipped if the last run was less than five minutes ago. Only workouts whose
`health_connect_published_at` is older than their `updated_at` are sent, so a run with nothing
pending costs one query.

`health_connect_published_at` is device-local and deliberately not part of the sync payload — a
pull keeps whatever the local row already had, otherwise every pull would republish everything.

## Session window

A data point's `timestamp` counts seconds on the workout counter, which the treadmill's own
telemetry also writes and can rewind, while the session end is derived from that counter's final
value. A sample past the end made Health Connect reject the entire batch
(`Time instant values must be within session interval`). The window is therefore stretched to
cover the last sample, samples are clamped into it, duplicate instants collapse to the later
reading, and a zero-length session gets a one second floor. Each session is written on its own,
so one rejected workout no longer blocks the rest.

## Removing published data

The settings sheet's destructive action deletes every record this app wrote and resets the
publish markers, so the next run recreates them. Health Connect only lets an app delete records
it created, so no other writer's data can be affected.

One gap: `DistanceDataType` in `health_connector` 3.9.x implements neither delete capability, so
distance records survive the wipe and are only overwritten by their client record id on the next
publish. The confirmation dialog says so.

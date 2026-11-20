# Todo — reminders, alarms and home screen widget

The Dart side owns all data (sqlite, sync). The Android side is plain Kotlin under
`android/app/src/main/kotlin/de/renier/tool_lab/todo/` and never starts a Flutter engine:
alarms, notifications, notification actions and the home screen widget work from the files below.
This document is the contract between the two; change both sides together.

Tool id `todo`, route `/todo`, Android activity `de.renier.tool_lab.TodoActivity` (process `:todo`,
taskAffinity `de.renier.tool_lab.todo`), alias `de.renier.tool_lab.TodoAlias`, icon `@mipmap/ic_launcher_todo`.

## Shared directory
Android: `context.filesDir/todo/`  ==  Dart: `(await getApplicationSupportDirectory()).path/todo/`.
All JSON files are written atomically (write `<name>.tmp`, then rename).

### alarms.json  (Dart writes, Kotlin reads)
```json
{"version":1,"generatedAt":1700000000000,"snoozeMinutes":10,"alarmSound":true,"alarmVibrate":true,"stopped":["def67890"],"entries":[
  {"key":"<taskId>@<atMs>","taskId":"abc12345","at":1700000000000,"alarm":false,
   "title":"Pay rent","body":"Home · due today 18:00","color":4280391411,"repeat":15},
  {"key":"_digest@<atMs>","taskId":"_digest","at":1700000000000,"alarm":false,
   "title":"Your day","body":"2 due today · 1 overdue\nPay rent, …","color":4280391411,
   "kind":"digest","listId":"smart:myDay"}
]}
```
Sorted by `at`, only future entries (>= now - 1 min), horizon 30 days, max 500.
`alarm=true` -> loud alarm (alarm clock + full-screen). `color` = ARGB int of the list color (notification accent).
- `snoozeMinutes`: length of the Snooze action and alarm button (setting, default 10).
- `alarmSound` / `alarmVibrate` (optional, default true): pick the alarm channel; see behaviour notes.
- `repeat` (optional): minutes until the reminder rings again while the task is open; see behaviour notes.
- `kind:"digest"`: the daily summary (setting, off by default), at most the next 2 days. Shown on its own
  channel without actions; a tap opens `listId`. The first body line is the collapsed text.
- `stopped`: tasks that have entries in snoozes.json but are done or deleted by now (also from another device);
  Kotlin ignores and drops their snoozes and repeats.

### snoozes.json  (Kotlin only)
Same entry shape (`{"entries":[...]}`). Kotlin merges it with alarms.json when scheduling and drops entries once fired.

### pending_actions.jsonl  (Kotlin appends one JSON object per line, Dart drains)
`{"type":"complete","taskId":"abc12345","at":1700000000000}`; `type` is `complete` or `tomorrow` (move the due date to the next day).
Dart drains by renaming to `pending_actions.jsonl.draining`, reading, deleting.

### widget.json  (Dart writes, Kotlin reads)
```json
{"version":1,"generatedAt":0,
 "lists":[
   {"id":"smart:myday","name":"My Day","color":4280391411,"icon":"☀","openCount":3,
    "tasks":[{"id":"abc12345","title":"Pay rent","meta":"Today 18:00","overdue":false,"important":true}]}
 ]}
```
Smart ids: `smart:myday`, `smart:important`, `smart:planned`, `smart:all`; user lists use their shortId.
Up to 50 open tasks per list, ordered by the list's sort mode from the app (setting `sort_modes`, keyed by widget id). `meta` is pre-formatted and localized by Dart (may be empty).
First list = default for a newly added widget.

## Kotlin native state
SharedPreferences `todo_native` (process `:todo`): `lastFiredAt` (Long), `widget_<appWidgetId>` = list id.

## MethodChannel `de.renier.tool_lab/todo`
Dart -> Kotlin:
- `reschedule` -> re-read alarms.json + snoozes.json, schedule next alarm. Returns null.
- `refreshWidgets` -> re-render all todo widgets from widget.json.
- `cancelNotifications` `{taskId}` -> cancel notifications for that task.
- `consumeLaunchIntent` -> `{"taskId":String?,"quickAdd":bool,"listId":String?}` or null; cleared after read.
- `permissionStatus` -> `{"notifications":bool,"exactAlarms":bool,"fullScreen":bool}`
- `openExactAlarmSettings`, `openFullScreenSettings`, `openNotificationSettings`.
Kotlin -> Dart:
- `launchIntent` with the same map as `consumeLaunchIntent` (when TodoActivity gets a new intent while running).
- `actionsPending` (no args) -> Dart drains pending_actions.jsonl.

Launch intents (notification tap, widget row, widget "+") target TodoActivity explicitly with extras
`route="/todo"`, `todo_task_id`, `todo_quick_add` (bool), `todo_list_id`.

## Linux / Windows
Dart schedules in-process timers while the app runs.
- Linux: Dart uses `dbus` -> `org.freedesktop.Notifications.Notify`.
- Windows: MethodChannel `de.renier.tool_lab/todo_desktop`, method `notify` `{"title","body"}`
  -> native Shell_NotifyIcon balloon (shown as a toast on Win10/11). Returns bool.

## Behaviour notes
- One AlarmManager alarm at a time: the earliest entry. Reminders use `setExactAndAllowWhileIdle`
  (inexact fallback without the exact-alarm grant), alarms use `setAlarmClock` + a full-screen
  `TodoAlarmActivity` with an insistent alarm-channel notification.
- An inexact hourly recheck picks up files rewritten by a headless background run, which has no channel.
- Entries missed by more than 24 h (device off) are skipped silently.
- Repeat: after showing an entry with `repeat > 0`, Kotlin writes a snooze for `now + repeat` with the same
  fields, so it keeps ringing until Done, Tomorrow, Snooze (which restarts the cycle) or the alarm screen's
  Dismiss. Swiping the notification away does not stop it. `cancelNotifications` from Dart (task done or
  deleted in the app) also drops the task's snoozes.
- Alarm sound and vibration: a channel's sound is fixed once created, so each combination has its own
  channel (`todo_alarms` = both, `todo_alarms_sound`, `todo_alarms_vibrate`, `todo_alarms_quiet`); the unused
  ones are deleted. The tone link opens the current channel's system page.
- An alarm rings (insistent) for at most 1 minute: a handler plus an exact `SILENCE` alarm repost the still
  ringing notification on the silent `todo_alarms_rung` channel, swipeable, actions kept. The alarm screen
  stops keeping the screen on at the same time.
- Widget check circle asks for confirmation (dialog in `TodoWidgetActionActivity`) before completing.
- Notification actions: Done, Snooze (`snoozeMinutes`), Tomorrow (the alarm screen also offers Tomorrow). Done and Tomorrow are queued in `pending_actions.jsonl`
  and applied by Dart on the next open, on `actionsPending`, or by the background task.
- Rules with `X-FROM=COMPLETION` (repeat after completion) have no known future occurrences:
  only their stored reminders are published; the next due date is set when the task is done.
- Recurring tasks: Dart projects every occurrence's reminder (same offset from the due date) for 30 days;
  the background task (`todo-refresh`, default 6 h) re-extends the horizon and syncs.
- The widget has no periodic update; Dart calls `refreshWidgets` after writing `widget.json`.
  Row taps go through `TodoWidgetActionActivity`, a trampoline for the single fill-in template.
- Widget title tap opens `TodoWidgetConfigActivity` (list picker), the open icon opens the app.
- Android 12+ widget rows are inline `RemoteCollectionItems`; `TodoWidgetService` only serves Android 8–11.
- Native may push `launchIntent` and also return it from `consumeLaunchIntent`; Dart ignores a repeat.

## Local-only data
- `todo_trash` table: snapshots of deleted tasks (JSON of the sync payload) for "Recently deleted"; kept 30 days,
  never synced. Restoring re-saves the task with a newer `updatedAt`, which outranks the server tombstone.
- Setting `cleanup_days` (default 90, 0 = off): completed tasks older than that are deleted (synced as deletions)
  on app start and in the background task.
- Setting `filters`: saved filters (list, tag, due range, important), JSON; device-local. Widget id `filter:<id>`.
- Task field `startAt` / column `start_at` (synced): local midnight; the task is hidden from every view except
  search and the collapsed "Later" section until that day, and from the widget and the daily summary.

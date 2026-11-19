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
{"version":1,"generatedAt":1700000000000,"entries":[
  {"key":"<taskId>@<atMs>","taskId":"abc12345","at":1700000000000,"alarm":false,
   "title":"Pay rent","body":"Home · due today 18:00","color":4280391411}
]}
```
Sorted by `at`, only future entries (>= now - 1 min), horizon 30 days, max 500.
`alarm=true` -> loud alarm (alarm clock + full-screen). `color` = ARGB int of the list color (notification accent).

### snoozes.json  (Kotlin only)
Same entry shape (`{"entries":[...]}`). Kotlin merges it with alarms.json when scheduling and drops entries once fired.

### pending_actions.jsonl  (Kotlin appends one JSON object per line, Dart drains)
`{"type":"complete","taskId":"abc12345","at":1700000000000}`
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
Up to 50 open tasks per list. `meta` is pre-formatted and localized by Dart (may be empty).
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
- Notification actions: Done, Snooze 10 min, Snooze 1 h. Done is queued in `pending_actions.jsonl`
  and applied by Dart on the next open, on `actionsPending`, or by the background task.
- Recurring tasks: Dart projects every occurrence's reminder (same offset from the due date) for 30 days;
  the background task (`todo-refresh`, default 6 h) re-extends the horizon and syncs.
- The widget has no periodic update; Dart calls `refreshWidgets` after writing `widget.json`.
  Row taps go through `TodoWidgetActionActivity`, a trampoline for the single fill-in template.
- Widget title tap opens `TodoWidgetConfigActivity` (list picker), the open icon opens the app.
- Android 12+ widget rows are inline `RemoteCollectionItems`; `TodoWidgetService` only serves Android 8–11.
- Native may push `launchIntent` and also return it from `consumeLaunchIntent`; Dart ignores a repeat.

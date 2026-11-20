# tool_lab_bridge

ToolLab's own Android plugin. App code registers its method channels only on
the activity's engine, so a headless engine — a WorkManager background run —
cannot reach native tool code. A plugin is registered on every engine, so this
one carries the few calls such runs need:

- `broadcast(action, extras)` — an explicit broadcast to a receiver in the app
  package. Tools declare the receiver (in their own process if isolated) and do
  the native work there, e.g. refresh a home screen widget or post a
  notification.
- `notificationsEnabled()` / `openNotificationSettings()` — whether the app may
  post notifications, and the system page to allow it.

All calls are no-ops off Android.

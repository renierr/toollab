package de.renier.tool_lab.todo

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper

object TodoAlarmScheduler {
    private const val PREFS = "todo_native"
    private const val KEY_LAST_FIRED = "lastFiredAt"
    private const val REQUEST_FIRE = 0x7D01
    private const val REQUEST_RECHECK = 0x7D02
    private const val RECHECK_INTERVAL_MS = 60 * 60 * 1000L
    private const val DUE_SLACK_MS = 5_000L

    // Anything missed by longer than this (device off for days) is dropped silently.
    private const val STALE_MS = 24 * 60 * 60 * 1000L

    const val ACTION_FIRE = "de.renier.tool_lab.todo.FIRE"
    const val ACTION_RECHECK = "de.renier.tool_lab.todo.RECHECK"
    const val ACTION_SILENCE = "de.renier.tool_lab.todo.SILENCE"

    /** How long an alarm rings before its notification is reposted silently. */
    const val RING_MS = 60_000L

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun widgetPrefs(context: Context) = prefs(context)

    private fun lastFiredAt(context: Context): Long = prefs(context).getLong(KEY_LAST_FIRED, 0L)

    private fun setLastFiredAt(context: Context, value: Long) {
        prefs(context).edit().putLong(KEY_LAST_FIRED, value).apply()
    }

    fun clampLastFired(context: Context) {
        val now = System.currentTimeMillis()
        if (lastFiredAt(context) > now) setLastFiredAt(context, now)
    }

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    }

    private fun pending(context: Context): List<TodoAlarmEntry> {
        val last = lastFiredAt(context)
        val stopped = TodoFiles.stoppedTasks(context)
        return (TodoFiles.readEntries(context, TodoFiles.ALARMS) +
            TodoFiles.readEntries(context, TodoFiles.SNOOZES).filter { it.taskId !in stopped })
            .filter { it.at > last }
            .sortedBy { it.at }
    }

    fun reschedule(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java)
        val now = System.currentTimeMillis()
        val next = pending(context).firstOrNull()
        val fire = TodoIntents.broadcast(
            context,
            REQUEST_FIRE,
            Intent(context, TodoAlarmReceiver::class.java).setAction(ACTION_FIRE),
        )
        am.cancel(fire)
        if (next != null) {
            val at = maxOf(next.at, now + 1_000L)
            val exact = canScheduleExact(context)
            try {
                when {
                    next.alarm && exact -> am.setAlarmClock(
                        AlarmManager.AlarmClockInfo(
                            at,
                            TodoIntents.activity(context, REQUEST_FIRE, TodoIntents.launch(context, next.taskId)),
                        ),
                        fire,
                    )
                    exact -> am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fire)
                    else -> am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fire)
                }
            } catch (e: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fire)
            }
        }
        // Headless Dart runs rewrite alarms.json without a channel to call us, so poll it cheaply.
        val recheck = TodoIntents.broadcast(
            context,
            REQUEST_RECHECK,
            Intent(context, TodoAlarmReceiver::class.java).setAction(ACTION_RECHECK),
        )
        am.cancel(recheck)
        if (next == null || next.at > now + RECHECK_INTERVAL_MS) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, now + RECHECK_INTERVAL_MS, recheck)
        }
    }

    // The handler is the prompt path while the process lives; the alarm covers a killed process.
    fun scheduleSilence(context: Context, entry: TodoAlarmEntry) {
        val app = context.applicationContext
        val at = System.currentTimeMillis() + RING_MS
        val am = app.getSystemService(AlarmManager::class.java)
        val silence = TodoIntents.broadcast(
            app,
            TodoIntents.notificationId(entry.taskId),
            Intent(app, TodoAlarmReceiver::class.java)
                .setAction(ACTION_SILENCE)
                .putExtras(TodoActions.entryExtras(entry)),
        )
        try {
            if (canScheduleExact(app)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, silence)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, silence)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, silence)
        }
        Handler(Looper.getMainLooper()).postDelayed({ TodoNotifications.silence(app, entry) }, RING_MS)
    }

    fun fireDue(context: Context) {
        val now = System.currentTimeMillis()
        val due = pending(context).filter { it.at <= now + DUE_SLACK_MS }
        if (due.isNotEmpty()) {
            // One notification per task: the latest due entry wins.
            val shown = due.groupBy { it.taskId }
                .map { (_, entries) -> entries.maxBy { it.at } }
                .filter { now - it.at < STALE_MS }
            shown.forEach { TodoNotifications.show(context, it) }
            val newest = due.maxOf { it.at }
            setLastFiredAt(context, newest)
            // Repeating reminders come back as snoozes until done, snoozed or dismissed.
            val repeats = shown.filter { it.repeat > 0 && !it.digest }.map {
                val at = maxOf(now, newest) + it.repeat * 60_000L
                it.copy(key = "${it.taskId}@$at", at = at)
            }
            val repeated = repeats.map { it.taskId }.toSet()
            val stopped = TodoFiles.stoppedTasks(context)
            val snoozes = TodoFiles.readEntries(context, TodoFiles.SNOOZES)
            val kept = snoozes.filter { it.at > newest && it.taskId !in repeated && it.taskId !in stopped }
            if (kept.size != snoozes.size || repeats.isNotEmpty()) {
                TodoFiles.writeSnoozes(context, kept + repeats)
            }
        }
        reschedule(context)
    }
}

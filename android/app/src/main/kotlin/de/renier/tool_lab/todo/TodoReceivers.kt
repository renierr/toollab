package de.renier.tool_lab.todo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TodoAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            TodoAlarmScheduler.ACTION_FIRE -> TodoAlarmScheduler.fireDue(context)
            TodoAlarmScheduler.ACTION_RECHECK -> TodoAlarmScheduler.fireDue(context)
        }
    }
}

class TodoActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_COMPLETE = "de.renier.tool_lab.todo.COMPLETE"
        const val ACTION_SNOOZE = "de.renier.tool_lab.todo.SNOOZE"
        const val ACTION_TOMORROW = "de.renier.tool_lab.todo.TOMORROW"
        const val EXTRA_MINUTES = "todo_snooze_minutes"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra(TodoIntents.EXTRA_TASK_ID) ?: return
        when (intent.action) {
            ACTION_COMPLETE -> TodoActions.complete(context, taskId)
            ACTION_TOMORROW -> TodoActions.moveToTomorrow(context, taskId)
            ACTION_SNOOZE -> {
                val entry = TodoActions.entryFrom(intent) ?: return
                TodoActions.snooze(context, entry, intent.getIntExtra(EXTRA_MINUTES, 10).coerceAtLeast(1))
            }
        }
    }
}

class TodoBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> TodoAlarmScheduler.fireDue(context)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                TodoAlarmScheduler.clampLastFired(context)
                TodoAlarmScheduler.reschedule(context)
            }
        }
        TodoWidgetProvider.refreshAll(context)
    }
}

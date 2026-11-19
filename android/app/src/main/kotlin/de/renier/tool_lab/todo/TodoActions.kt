package de.renier.tool_lab.todo

import android.content.Context
import android.content.Intent
import android.os.Bundle
import org.json.JSONObject

object TodoActions {
    private const val EXTRA_KEY = "todo_entry_key"
    private const val EXTRA_AT = "todo_entry_at"
    private const val EXTRA_ALARM = "todo_entry_alarm"
    private const val EXTRA_TITLE = "todo_entry_title"
    private const val EXTRA_BODY = "todo_entry_body"
    private const val EXTRA_COLOR = "todo_entry_color"

    fun entryExtras(entry: TodoAlarmEntry): Bundle = Bundle().apply {
        putString(EXTRA_KEY, entry.key)
        putString(TodoIntents.EXTRA_TASK_ID, entry.taskId)
        putLong(EXTRA_AT, entry.at)
        putBoolean(EXTRA_ALARM, entry.alarm)
        putString(EXTRA_TITLE, entry.title)
        putString(EXTRA_BODY, entry.body)
        putInt(EXTRA_COLOR, entry.color)
    }

    fun entryFrom(intent: Intent): TodoAlarmEntry? {
        val taskId = intent.getStringExtra(TodoIntents.EXTRA_TASK_ID) ?: return null
        val at = intent.getLongExtra(EXTRA_AT, 0L)
        return TodoAlarmEntry(
            key = intent.getStringExtra(EXTRA_KEY) ?: "$taskId@$at",
            taskId = taskId,
            at = at,
            alarm = intent.getBooleanExtra(EXTRA_ALARM, false),
            title = intent.getStringExtra(EXTRA_TITLE) ?: "",
            body = intent.getStringExtra(EXTRA_BODY) ?: "",
            color = intent.getIntExtra(EXTRA_COLOR, 0xFF4FC3F7.toInt()),
        )
    }

    fun complete(context: Context, taskId: String) {
        queue(context, "complete", taskId)
        TodoFiles.removeTaskFromWidget(context, taskId)
        TodoWidgetProvider.refreshAll(context)
        TodoNative.notifyActionsPending()
    }

    /** Dart moves the due date and republishes the reminders; until then the
     *  task's pending reminders are dropped so none fires for the old day. */
    fun moveToTomorrow(context: Context, taskId: String) {
        queue(context, "tomorrow", taskId)
        val alarms = TodoFiles.readEntries(context, TodoFiles.ALARMS)
        if (alarms.any { it.taskId == taskId }) {
            TodoFiles.writeEntries(context, TodoFiles.ALARMS, alarms.filter { it.taskId != taskId })
            TodoAlarmScheduler.reschedule(context)
        }
        TodoNative.notifyActionsPending()
    }

    private fun queue(context: Context, type: String, taskId: String) {
        TodoFiles.appendAction(
            context,
            JSONObject()
                .put("type", type)
                .put("taskId", taskId)
                .put("at", System.currentTimeMillis()),
        )
        TodoNotifications.cancel(context, taskId)
        val snoozes = TodoFiles.readEntries(context, TodoFiles.SNOOZES)
        if (snoozes.any { it.taskId == taskId }) {
            TodoFiles.writeSnoozes(context, snoozes.filter { it.taskId != taskId })
            TodoAlarmScheduler.reschedule(context)
        }
    }

    fun snooze(context: Context, entry: TodoAlarmEntry, minutes: Int) {
        val at = System.currentTimeMillis() + minutes * 60_000L
        val snoozed = entry.copy(key = "${entry.taskId}@$at", at = at)
        val others = TodoFiles.readEntries(context, TodoFiles.SNOOZES).filter { it.taskId != entry.taskId }
        TodoFiles.writeSnoozes(context, others + snoozed)
        TodoNotifications.cancel(context, entry.taskId)
        TodoAlarmScheduler.reschedule(context)
    }

    fun dismiss(context: Context, taskId: String) {
        TodoNotifications.cancel(context, taskId)
    }
}

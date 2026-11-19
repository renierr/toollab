package de.renier.tool_lab.todo

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import de.renier.tool_lab.TodoActivity

object TodoIntents {
    const val EXTRA_TASK_ID = "todo_task_id"
    const val EXTRA_QUICK_ADD = "todo_quick_add"
    const val EXTRA_LIST_ID = "todo_list_id"
    const val ROUTE = "/todo"

    fun launch(
        context: Context,
        taskId: String? = null,
        listId: String? = null,
        quickAdd: Boolean = false,
    ): Intent = Intent(context, TodoActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
        putExtra("route", ROUTE)
        taskId?.let { putExtra(EXTRA_TASK_ID, it) }
        listId?.let { putExtra(EXTRA_LIST_ID, it) }
        if (quickAdd) putExtra(EXTRA_QUICK_ADD, true)
    }

    fun activity(context: Context, requestCode: Int, intent: Intent): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun broadcast(context: Context, requestCode: Int, intent: Intent): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun notificationId(taskId: String): Int = taskId.hashCode()
}

package de.renier.tool_lab.todo

import android.app.Activity
import android.app.AlertDialog
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import de.renier.tool_lab.R

class TodoWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val KEY_PREFIX = "widget_"

        fun listIdFor(context: Context, widgetId: Int): String? =
            TodoAlarmScheduler.widgetPrefs(context).getString("$KEY_PREFIX$widgetId", null)

        fun setListId(context: Context, widgetId: Int, listId: String) {
            TodoAlarmScheduler.widgetPrefs(context).edit().putString("$KEY_PREFIX$widgetId", listId).commit()
        }

        fun resolveList(context: Context, widgetId: Int): TodoWidgetList? {
            val lists = TodoFiles.readWidgetLists(context)
            val id = listIdFor(context, widgetId)
            return lists.firstOrNull { it.id == id } ?: lists.firstOrNull()
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodoWidgetProvider::class.java))
            if (ids.isEmpty()) return
            ids.forEach { update(context, manager, it) }
            @Suppress("DEPRECATION")
            manager.notifyAppWidgetViewDataChanged(ids, R.id.todo_widget_list)
        }

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val list = resolveList(context, widgetId)
            val views = RemoteViews(context.packageName, R.layout.todo_widget)
            val base = widgetId * 8

            views.setTextViewText(
                R.id.todo_widget_title,
                list?.name ?: context.getString(R.string.todo_widget_label),
            )
            views.setTextViewText(R.id.todo_widget_count, list?.openCount?.takeIf { it > 0 }?.toString() ?: "")
            if (list != null && list.icon.isNotBlank()) {
                views.setTextViewText(R.id.todo_widget_icon, list.icon)
                views.setViewVisibility(R.id.todo_widget_icon, View.VISIBLE)
                views.setViewVisibility(R.id.todo_widget_dot, View.GONE)
            } else {
                views.setViewVisibility(R.id.todo_widget_icon, View.GONE)
                views.setViewVisibility(R.id.todo_widget_dot, View.VISIBLE)
                views.setInt(R.id.todo_widget_dot, "setColorFilter", list?.color ?: 0xFF4FC3F7.toInt())
            }
            views.setTextViewText(
                R.id.todo_widget_empty,
                context.getString(if (list == null) R.string.todo_widget_no_data else R.string.todo_widget_empty),
            )

            views.setOnClickPendingIntent(
                R.id.todo_widget_switch,
                TodoIntents.activity(
                    context,
                    base + 4,
                    Intent(context, TodoWidgetConfigActivity::class.java)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                ),
            )
            views.setOnClickPendingIntent(
                R.id.todo_widget_open,
                TodoIntents.activity(context, base + 1, TodoIntents.launch(context, listId = list?.id)),
            )
            views.setOnClickPendingIntent(
                R.id.todo_widget_add,
                TodoIntents.activity(context, base + 2, TodoIntents.launch(context, listId = list?.id, quickAdd = true)),
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Inline items: a cached service factory would keep showing the previous list.
                val items = RemoteViews.RemoteCollectionItems.Builder().setHasStableIds(true).setViewTypeCount(1)
                list?.tasks?.forEach { items.addItem(itemId(it), itemViews(context, it)) }
                views.setRemoteAdapter(R.id.todo_widget_list, items.build())
            } else {
                val serviceIntent = Intent(context, TodoWidgetService::class.java)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                serviceIntent.data = Uri.parse(serviceIntent.toUri(Intent.URI_INTENT_SCHEME))
                @Suppress("DEPRECATION")
                views.setRemoteAdapter(R.id.todo_widget_list, serviceIntent)
            }
            views.setEmptyView(R.id.todo_widget_list, R.id.todo_widget_empty)

            // Collection rows can only fill in one template, so both row taps go through a trampoline.
            val template = PendingIntent.getActivity(
                context,
                base + 3,
                Intent(context, TodoWidgetActionActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            views.setPendingIntentTemplate(R.id.todo_widget_list, template)

            manager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { update(context, manager, it) }
        @Suppress("DEPRECATION")
        manager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.todo_widget_list)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, manager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val editor = TodoAlarmScheduler.widgetPrefs(context).edit()
        appWidgetIds.forEach { editor.remove("$KEY_PREFIX$it") }
        editor.apply()
    }
}

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TodoWidgetFactory(
            applicationContext,
            intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID),
        )
}

private class TodoWidgetFactory(
    private val context: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {
    private var tasks: List<TodoWidgetTask> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        tasks = TodoWidgetProvider.resolveList(context, widgetId)?.tasks ?: emptyList()
    }

    override fun onDestroy() {
        tasks = emptyList()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks.getOrNull(position) ?: return RemoteViews(context.packageName, R.layout.todo_widget_item)
        return itemViews(context, task)
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = tasks.getOrNull(position)?.let(::itemId) ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}

private fun itemId(task: TodoWidgetTask): Long = task.id.hashCode().toLong()

private fun itemViews(context: Context, task: TodoWidgetTask): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.todo_widget_item)
    views.setTextViewText(R.id.todo_item_title, task.title)
    if (task.meta.isNotEmpty()) {
        views.setViewVisibility(R.id.todo_item_meta, View.VISIBLE)
        views.setTextViewText(R.id.todo_item_meta, task.meta)
        views.setTextColor(
            R.id.todo_item_meta,
            context.getColor(if (task.overdue) R.color.todo_widget_overdue else R.color.todo_widget_text_secondary),
        )
    } else {
        views.setViewVisibility(R.id.todo_item_meta, View.GONE)
    }
    views.setViewVisibility(R.id.todo_item_star, if (task.important) View.VISIBLE else View.GONE)
    views.setViewVisibility(R.id.todo_item_bar, if (task.overdue) View.VISIBLE else View.GONE)
    views.setInt(R.id.todo_item_root, "setBackgroundResource", if (task.overdue) R.drawable.todo_widget_item_overdue_bg else 0)
    views.setOnClickFillInIntent(
        R.id.todo_item_root,
        Intent()
            .putExtra(TodoWidgetActionActivity.EXTRA_OP, TodoWidgetActionActivity.OP_OPEN)
            .putExtra(TodoIntents.EXTRA_TASK_ID, task.id),
    )
    views.setOnClickFillInIntent(
        R.id.todo_item_check,
        Intent()
            .putExtra(TodoWidgetActionActivity.EXTRA_OP, TodoWidgetActionActivity.OP_COMPLETE)
            .putExtra(TodoIntents.EXTRA_TASK_ID, task.id)
            .putExtra(TodoWidgetActionActivity.EXTRA_TITLE, task.title),
    )
    return views
}

class TodoWidgetActionActivity : Activity() {
    companion object {
        const val EXTRA_OP = "todo_widget_op"
        const val EXTRA_TITLE = "todo_widget_title"
        const val OP_OPEN = "open"
        const val OP_COMPLETE = "complete"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val taskId = intent.getStringExtra(TodoIntents.EXTRA_TASK_ID)
        when {
            taskId == null -> close()
            intent.getStringExtra(EXTRA_OP) == OP_COMPLETE -> confirmComplete(taskId)
            else -> {
                startActivity(TodoIntents.launch(this, taskId))
                close()
            }
        }
    }

    // A stray tap on the check circle must not finish a task.
    private fun confirmComplete(taskId: String) {
        AlertDialog.Builder(this, R.style.TodoDialogTheme)
            .setTitle(R.string.todo_widget_confirm_title)
            .setMessage(intent.getStringExtra(EXTRA_TITLE).orEmpty())
            .setPositiveButton(R.string.todo_action_done) { _, _ -> TodoActions.complete(this, taskId) }
            .setNegativeButton(android.R.string.cancel, null)
            .setOnDismissListener { close() }
            .show()
    }

    private fun close() {
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}

package de.renier.tool_lab.todo

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import de.renier.tool_lab.R

class TodoWidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        setResult(RESULT_CANCELED, resultIntent())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setTitle(R.string.todo_widget_config_title)

        val lists = TodoFiles.readWidgetLists(this)
        if (lists.isEmpty()) {
            setContentView(
                TextView(this).apply {
                    text = getString(R.string.todo_widget_no_data)
                    gravity = Gravity.CENTER
                    setPadding(dp(24f), dp(32f), dp(24f), dp(32f))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setOnClickListener { finishWith(null) }
                },
            )
            return
        }
        val current = TodoWidgetProvider.listIdFor(this, widgetId)
        val listView = ListView(this).apply {
            adapter = object : BaseAdapter() {
                override fun getCount() = lists.size
                override fun getItem(position: Int) = lists[position]
                override fun getItemId(position: Int) = position.toLong()
                override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                    val list = lists[position]
                    val row = (convertView as? LinearLayout) ?: LinearLayout(this@TodoWidgetConfigActivity).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.CENTER_VERTICAL
                        setPadding(dp(20f), dp(14f), dp(20f), dp(14f))
                        addView(TextView(context).apply { setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f) })
                        addView(
                            TextView(context).apply {
                                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                                setPadding(dp(14f), 0, 0, 0)
                            },
                            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
                        )
                        addView(TextView(context).apply { setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f) })
                    }
                    (row.getChildAt(0) as TextView).apply {
                        text = list.icon.ifBlank { "●" }
                        setTextColor(if (list.icon.isBlank()) list.color else (row.getChildAt(1) as TextView).currentTextColor)
                    }
                    (row.getChildAt(1) as TextView).apply {
                        text = list.name
                        setTypeface(null, if (list.id == current) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL)
                    }
                    (row.getChildAt(2) as TextView).text = list.openCount.takeIf { it > 0 }?.toString() ?: ""
                    return row
                }
            }
            setOnItemClickListener { _, _, position, _ -> finishWith(lists[position].id) }
        }
        setContentView(listView)
    }

    private fun finishWith(listId: String?) {
        if (listId != null) TodoWidgetProvider.setListId(this, widgetId, listId)
        TodoWidgetProvider.update(this, AppWidgetManager.getInstance(this), widgetId)
        @Suppress("DEPRECATION")
        AppWidgetManager.getInstance(this).notifyAppWidgetViewDataChanged(intArrayOf(widgetId), R.id.todo_widget_list)
        setResult(RESULT_OK, resultIntent())
        finish()
    }

    private fun resultIntent() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

    private fun dp(value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()
}

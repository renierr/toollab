package de.renier.tool_lab.todo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import de.renier.tool_lab.R
import java.util.Date

class TodoAlarmActivity : Activity() {
    companion object {
        fun intent(context: Context, entry: TodoAlarmEntry): Intent =
            Intent(context, TodoAlarmActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                .putExtras(TodoActions.entryExtras(entry))
    }

    private var entry: TodoAlarmEntry? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        bind(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    private fun bind(intent: Intent) {
        val current = TodoActions.entryFrom(intent) ?: run {
            finish()
            return
        }
        entry = current
        setContentView(buildContent(current))
    }

    private fun dp(value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()

    private fun buildContent(entry: TodoAlarmEntry): LinearLayout {
        val accent = entry.color or 0xFF000000.toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(0x10, 0x14, 0x1B))
            setPadding(dp(32f), dp(48f), dp(32f), dp(48f))
        }
        val time = TextView(this).apply {
            text = DateFormat.getTimeFormat(this@TodoAlarmActivity).format(Date(System.currentTimeMillis()))
            setTextColor(accent)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }
        val title = TextView(this).apply {
            text = entry.title
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, dp(24f), 0, dp(8f))
        }
        val body = TextView(this).apply {
            text = entry.body
            setTextColor(Color.argb(0xB3, 0xFF, 0xFF, 0xFF))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(40f))
        }
        root.addView(time, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        root.addView(title, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        if (entry.body.isNotEmpty()) root.addView(body, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))

        root.addView(button(getString(R.string.todo_action_done), accent, Color.rgb(0x10, 0x14, 0x1B)) {
            TodoActions.complete(this, entry.taskId)
            finish()
        })
        root.addView(button(getString(R.string.todo_action_snooze_10_long), Color.rgb(0x2A, 0x31, 0x3C), Color.WHITE) {
            TodoActions.snooze(this, entry, 10)
            finish()
        })
        root.addView(button(getString(R.string.todo_action_dismiss), Color.TRANSPARENT, Color.argb(0xB3, 0xFF, 0xFF, 0xFF)) {
            TodoActions.dismiss(this, entry.taskId)
            finish()
        })
        return root
    }

    private fun button(label: String, background: Int, foreground: Int, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            isAllCaps = false
            setTextColor(foreground)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            this.background = GradientDrawable().apply {
                cornerRadius = dp(28f).toFloat()
                setColor(background)
            }
            stateListAnimator = null
            setOnClickListener { onClick() }
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(56f)).apply {
                topMargin = dp(12f)
            }
        }
}

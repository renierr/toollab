package de.renier.tool_lab.todo

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object TodoNative {
    private const val CHANNEL = "de.renier.tool_lab/todo"

    private var channel: MethodChannel? = null
    private var pendingLaunch: Map<String, Any?>? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(activity: Activity, messenger: BinaryMessenger) {
        val context = activity.applicationContext
        channel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "reschedule" -> {
                        TodoAlarmScheduler.reschedule(context)
                        result.success(null)
                    }
                    "refreshWidgets" -> {
                        TodoWidgetProvider.refreshAll(context)
                        result.success(null)
                    }
                    "cancelNotifications" -> {
                        call.argument<String>("taskId")?.let {
                            TodoNotifications.cancel(context, it)
                            if (TodoFiles.removeSnoozes(context, it)) TodoAlarmScheduler.reschedule(context)
                        }
                        result.success(null)
                    }
                    "consumeLaunchIntent" -> {
                        result.success(pendingLaunch)
                        pendingLaunch = null
                    }
                    "permissionStatus" -> result.success(permissionStatus(context))
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            openSettings(context, Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        }
                        result.success(null)
                    }
                    "openFullScreenSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            openSettings(context, Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                        }
                        result.success(null)
                    }
                    "openAlarmChannelSettings" -> {
                        TodoNotifications.ensureChannels(context)
                        context.startActivity(
                            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                .putExtra(Settings.EXTRA_CHANNEL_ID, TodoNotifications.alarmChannel(context))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        context.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun openSettings(context: Context, action: String) {
        val uri = Uri.parse("package:${context.packageName}")
        try {
            context.startActivity(Intent(action, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun permissionStatus(context: Context): Map<String, Boolean> {
        val fullScreen = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        } else {
            true
        }
        return mapOf(
            "notifications" to NotificationManagerCompat.from(context).areNotificationsEnabled(),
            "exactAlarms" to TodoAlarmScheduler.canScheduleExact(context),
            "fullScreen" to fullScreen,
        )
    }

    fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val taskId = intent.getStringExtra(TodoIntents.EXTRA_TASK_ID)
        val listId = intent.getStringExtra(TodoIntents.EXTRA_LIST_ID)
        val quickAdd = intent.getBooleanExtra(TodoIntents.EXTRA_QUICK_ADD, false)
        if (taskId == null && listId == null && !quickAdd) return
        val launch = mapOf("taskId" to taskId, "quickAdd" to quickAdd, "listId" to listId)
        pendingLaunch = launch
        // Strip the extras so a recreated activity does not replay them.
        intent.removeExtra(TodoIntents.EXTRA_TASK_ID)
        intent.removeExtra(TodoIntents.EXTRA_LIST_ID)
        intent.removeExtra(TodoIntents.EXTRA_QUICK_ADD)
        val target = channel ?: return
        mainHandler.post {
            target.invokeMethod(
                "launchIntent",
                launch,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (pendingLaunch == launch) pendingLaunch = null
                    }

                    override fun error(code: String, message: String?, details: Any?) {}

                    override fun notImplemented() {}
                },
            )
        }
    }

    fun notifyActionsPending() {
        val target = channel ?: return
        mainHandler.post {
            try {
                target.invokeMethod("actionsPending", null)
            } catch (e: Exception) {
                android.util.Log.w("TodoNative", "actionsPending not delivered: ${e.message}")
            }
        }
    }
}

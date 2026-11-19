package de.renier.tool_lab.todo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import androidx.core.app.NotificationCompat
import de.renier.tool_lab.R

object TodoNotifications {
    const val CHANNEL_REMINDERS = "todo_reminders"
    const val CHANNEL_ALARMS = "todo_alarms"
    const val CHANNEL_DIGEST = "todo_digest"
    private const val DIGEST_ID = 0x7D10
    private const val GROUP = "todo"
    private const val ALARM_TIMEOUT_MS = 10 * 60 * 1000L

    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    fun ensureChannels(context: Context) {
        val nm = manager(context)
        if (nm.getNotificationChannel(CHANNEL_REMINDERS) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_REMINDERS,
                    context.getString(R.string.todo_channel_reminders),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        if (nm.getNotificationChannel(CHANNEL_DIGEST) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_DIGEST,
                    context.getString(R.string.todo_channel_digest),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        if (nm.getNotificationChannel(CHANNEL_ALARMS) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ALARMS,
                    context.getString(R.string.todo_channel_alarms),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 600, 400, 600, 400, 600)
                },
            )
        }
    }

    fun show(context: Context, entry: TodoAlarmEntry) {
        ensureChannels(context)
        if (entry.digest) {
            showDigest(context, entry)
            return
        }
        val snooze = TodoFiles.snoozeMinutes(context)
        val id = TodoIntents.notificationId(entry.taskId)
        val builder = NotificationCompat.Builder(
            context,
            if (entry.alarm) CHANNEL_ALARMS else CHANNEL_REMINDERS,
        )
            .setSmallIcon(R.drawable.ic_stat_todo)
            .setColor(entry.color)
            .setContentTitle(entry.title)
            .setWhen(entry.at)
            .setShowWhen(true)
            .setAutoCancel(true)
            .setGroup(GROUP)
            .setContentIntent(
                TodoIntents.activity(context, id, TodoIntents.launch(context, entry.taskId)),
            )
            .addAction(
                0,
                context.getString(R.string.todo_action_done),
                actionIntent(context, TodoActionReceiver.ACTION_COMPLETE, entry, id * 4 + 1),
            )
            .addAction(
                0,
                context.getString(R.string.todo_action_snooze, snooze),
                actionIntent(context, TodoActionReceiver.ACTION_SNOOZE, entry, id * 4 + 2, snooze),
            )
            .addAction(
                0,
                context.getString(R.string.todo_action_tomorrow),
                actionIntent(context, TodoActionReceiver.ACTION_TOMORROW, entry, id * 4 + 3),
            )
        if (entry.body.isNotEmpty()) {
            builder.setContentText(entry.body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(entry.body))
        }
        if (entry.alarm) {
            val fullScreen = TodoIntents.activity(
                context,
                id * 4,
                TodoAlarmActivity.intent(context, entry),
            )
            builder.setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setFullScreenIntent(fullScreen, true)
                .setTimeoutAfter(ALARM_TIMEOUT_MS)
                .setOngoing(true)
                .setAutoCancel(false)
        } else {
            builder.setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        }
        val notification = builder.build()
        if (entry.alarm) notification.flags = notification.flags or Notification.FLAG_INSISTENT
        try {
            manager(context).notify(id, notification)
        } catch (e: SecurityException) {
            android.util.Log.w("TodoNotifications", "Notification permission missing")
        }
    }

    private fun showDigest(context: Context, entry: TodoAlarmEntry) {
        val notification = NotificationCompat.Builder(context, CHANNEL_DIGEST)
            .setSmallIcon(R.drawable.ic_stat_todo)
            .setColor(entry.color)
            .setContentTitle(entry.title)
            .setContentText(entry.body.substringBefore('\n'))
            .setStyle(NotificationCompat.BigTextStyle().bigText(entry.body))
            .setWhen(entry.at)
            .setShowWhen(true)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(
                TodoIntents.activity(context, DIGEST_ID, TodoIntents.launch(context, listId = entry.listId)),
            )
            .build()
        try {
            manager(context).notify(DIGEST_ID, notification)
        } catch (e: SecurityException) {
            android.util.Log.w("TodoNotifications", "Notification permission missing")
        }
    }

    fun cancel(context: Context, taskId: String) {
        manager(context).cancel(TodoIntents.notificationId(taskId))
    }

    private fun actionIntent(
        context: Context,
        action: String,
        entry: TodoAlarmEntry,
        requestCode: Int,
        minutes: Int = 0,
    ) = TodoIntents.broadcast(
        context,
        requestCode,
        Intent(context, TodoActionReceiver::class.java)
            .setAction(action)
            .putExtras(TodoActions.entryExtras(entry))
            .putExtra(TodoActionReceiver.EXTRA_MINUTES, minutes),
    )
}

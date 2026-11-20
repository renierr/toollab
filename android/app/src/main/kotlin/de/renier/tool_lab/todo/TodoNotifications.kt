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
    const val CHANNEL_DIGEST = "todo_digest"

    // Channel sound is fixed once created, so each sound/vibration choice has its own channel.
    // The original id stays the sound+vibration one so a tone picked there survives.
    private const val CHANNEL_ALARMS = "todo_alarms"
    private const val CHANNEL_ALARMS_SOUND = "todo_alarms_sound"
    private const val CHANNEL_ALARMS_VIBRATE = "todo_alarms_vibrate"
    private const val CHANNEL_ALARMS_QUIET = "todo_alarms_quiet"
    private val ALARM_CHANNELS = listOf(CHANNEL_ALARMS, CHANNEL_ALARMS_SOUND, CHANNEL_ALARMS_VIBRATE, CHANNEL_ALARMS_QUIET)

    /** An alarm after [TodoAlarmScheduler.RING_MS]: still listed, no sound or vibration. */
    private const val CHANNEL_ALARMS_RUNG = "todo_alarms_rung"
    private const val DIGEST_ID = 0x7D10
    private const val GROUP = "todo"

    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    fun alarmChannel(context: Context): String {
        val sound = TodoFiles.alarmSound(context)
        val vibrate = TodoFiles.alarmVibrate(context)
        return when {
            sound && vibrate -> CHANNEL_ALARMS
            sound -> CHANNEL_ALARMS_SOUND
            vibrate -> CHANNEL_ALARMS_VIBRATE
            else -> CHANNEL_ALARMS_QUIET
        }
    }

    fun ensureChannels(context: Context) {
        val nm = manager(context)
        fun create(id: String, name: Int, importance: Int, setup: NotificationChannel.() -> Unit = {}) {
            if (nm.getNotificationChannel(id) == null) {
                nm.createNotificationChannel(NotificationChannel(id, context.getString(name), importance).apply(setup))
            }
        }
        create(CHANNEL_REMINDERS, R.string.todo_channel_reminders, NotificationManager.IMPORTANCE_DEFAULT)
        create(CHANNEL_DIGEST, R.string.todo_channel_digest, NotificationManager.IMPORTANCE_DEFAULT)
        create(CHANNEL_ALARMS_RUNG, R.string.todo_channel_alarms_rung, NotificationManager.IMPORTANCE_DEFAULT) {
            setSound(null, null)
            enableVibration(false)
        }
        val current = alarmChannel(context)
        ALARM_CHANNELS.filter { it != current && nm.getNotificationChannel(it) != null }
            .forEach { nm.deleteNotificationChannel(it) }
        create(current, R.string.todo_channel_alarms, NotificationManager.IMPORTANCE_HIGH) {
            if (current == CHANNEL_ALARMS || current == CHANNEL_ALARMS_SOUND) {
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            } else {
                setSound(null, null)
            }
            val vibrate = current == CHANNEL_ALARMS || current == CHANNEL_ALARMS_VIBRATE
            enableVibration(vibrate)
            if (vibrate) vibrationPattern = longArrayOf(0, 600, 400, 600, 400, 600)
        }
    }

    fun show(context: Context, entry: TodoAlarmEntry) {
        ensureChannels(context)
        if (entry.digest) {
            showDigest(context, entry)
            return
        }
        post(context, entry, ringing = entry.alarm)
        if (entry.alarm) TodoAlarmScheduler.scheduleSilence(context, entry)
    }

    /** Reposts a still ringing alarm on the silent channel; no-op once acted on or rung again. */
    fun silence(context: Context, entry: TodoAlarmEntry) {
        val id = TodoIntents.notificationId(entry.taskId)
        val nm = manager(context)
        val active = nm.activeNotifications.firstOrNull { it.id == id }?.notification ?: return
        if (active.channelId !in ALARM_CHANNELS || active.`when` != entry.at) return
        nm.cancel(id)
        ensureChannels(context)
        post(context, entry, ringing = false)
    }

    private fun post(context: Context, entry: TodoAlarmEntry, ringing: Boolean) {
        val snooze = TodoFiles.snoozeMinutes(context)
        val id = TodoIntents.notificationId(entry.taskId)
        val channel = when {
            ringing -> alarmChannel(context)
            entry.alarm -> CHANNEL_ALARMS_RUNG
            else -> CHANNEL_REMINDERS
        }
        val builder = NotificationCompat.Builder(context, channel)
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
        if (ringing) {
            val fullScreen = TodoIntents.activity(
                context,
                id * 4,
                TodoAlarmActivity.intent(context, entry),
            )
            builder.setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setFullScreenIntent(fullScreen, true)
                .setOngoing(true)
                .setAutoCancel(false)
        } else {
            builder.setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        }
        val notification = builder.build()
        if (ringing) notification.flags = notification.flags or Notification.FLAG_INSISTENT
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

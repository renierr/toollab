package de.renier.tool_lab

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object NotificationHelper {
    private const val DEFAULT_CHANNEL_ID = "app_notification_channel"
    private const val DEFAULT_CHANNEL_NAME = "General Notifications"

    fun showNotification(
        context: Context,
        title: String,
        message: String,
        channelId: String = DEFAULT_CHANNEL_ID,
        channelName: String = DEFAULT_CHANNEL_NAME,
        pendingIntents: List<Pair<String, PendingIntent>> = emptyList()
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_DEFAULT
            )
            notificationManager.createNotificationChannel(channel)
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        for (action in pendingIntents) {
            builder.addAction(0, action.first, action.second)
        }

        notificationManager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}

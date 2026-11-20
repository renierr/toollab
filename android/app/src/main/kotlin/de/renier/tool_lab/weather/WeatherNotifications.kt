package de.renier.tool_lab.weather

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import de.renier.tool_lab.R

object WeatherNotifications {
    private const val CHANNEL = "weather_warnings"

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                context.getString(R.string.weather_channel_warnings),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = context.getString(R.string.weather_channel_warnings_description) },
        )
    }

    fun show(context: Context, key: String, title: String, body: String, color: Int, placeId: Int?) {
        val compat = NotificationManagerCompat.from(context)
        if (!compat.areNotificationsEnabled()) return
        ensureChannel(context)
        val id = key.hashCode()
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_weather)
            .setColor(color)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(WeatherIntents.activity(context, id, WeatherIntents.open(context, placeId)))
            .build()
        try {
            compat.notify(id, notification)
        } catch (e: SecurityException) {
            android.util.Log.w("WeatherNotifications", "not allowed: ${e.message}")
        }
    }
}

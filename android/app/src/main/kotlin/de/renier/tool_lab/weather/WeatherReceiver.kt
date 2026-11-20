package de.renier.tool_lab.weather

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Entry point for Dart, also from a headless background run, via the bridge plugin. */
class WeatherReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WeatherIntents.ACTION_REFRESH -> WeatherWidgetProvider.refreshAll(context)
            WeatherIntents.ACTION_NOTIFY -> WeatherNotifications.show(
                context,
                key = intent.getStringExtra("key") ?: return,
                title = intent.getStringExtra("title") ?: return,
                body = intent.getStringExtra("body") ?: "",
                color = intent.getIntExtra("color", 0xFFFFA000.toInt()),
                placeId = intent.getIntExtra("placeId", -1).takeIf { it >= 0 },
            )
        }
    }
}

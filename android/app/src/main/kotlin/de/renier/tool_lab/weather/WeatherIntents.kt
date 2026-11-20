package de.renier.tool_lab.weather

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import de.renier.tool_lab.WeatherActivity

object WeatherIntents {
    /** Sent by Dart through the ToolLab bridge plugin. */
    const val ACTION_REFRESH = "de.renier.tool_lab.weather.REFRESH_WIDGETS"
    const val ACTION_NOTIFY = "de.renier.tool_lab.weather.NOTIFY"

    fun open(context: Context, placeId: Int?): Intent = Intent(context, WeatherActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
        // The Dart router reads the place from the query.
        putExtra("route", if (placeId == null) "/weather" else "/weather?place=$placeId")
    }

    fun activity(context: Context, requestCode: Int, intent: Intent): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

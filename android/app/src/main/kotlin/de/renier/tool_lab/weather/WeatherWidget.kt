package de.renier.tool_lab.weather

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import de.renier.tool_lab.R

/** One resizable widget in three sizes: current weather, plus hours, plus days. */
class WeatherWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS = "weather_widget"
        private const val KEY_PREFIX = "place_"

        private val hourIds = arrayOf(
            intArrayOf(R.id.weather_widget_h0_time, R.id.weather_widget_h0_icon, R.id.weather_widget_h0_temp),
            intArrayOf(R.id.weather_widget_h1_time, R.id.weather_widget_h1_icon, R.id.weather_widget_h1_temp),
            intArrayOf(R.id.weather_widget_h2_time, R.id.weather_widget_h2_icon, R.id.weather_widget_h2_temp),
            intArrayOf(R.id.weather_widget_h3_time, R.id.weather_widget_h3_icon, R.id.weather_widget_h3_temp),
            intArrayOf(R.id.weather_widget_h4_time, R.id.weather_widget_h4_icon, R.id.weather_widget_h4_temp),
        )
        private val dayIds = arrayOf(
            intArrayOf(R.id.weather_widget_d0, R.id.weather_widget_d0_label, R.id.weather_widget_d0_icon, R.id.weather_widget_d0_low, R.id.weather_widget_d0_high),
            intArrayOf(R.id.weather_widget_d1, R.id.weather_widget_d1_label, R.id.weather_widget_d1_icon, R.id.weather_widget_d1_low, R.id.weather_widget_d1_high),
            intArrayOf(R.id.weather_widget_d2, R.id.weather_widget_d2_label, R.id.weather_widget_d2_icon, R.id.weather_widget_d2_low, R.id.weather_widget_d2_high),
            intArrayOf(R.id.weather_widget_d3, R.id.weather_widget_d3_label, R.id.weather_widget_d3_icon, R.id.weather_widget_d3_low, R.id.weather_widget_d3_high),
            intArrayOf(R.id.weather_widget_d4, R.id.weather_widget_d4_label, R.id.weather_widget_d4_icon, R.id.weather_widget_d4_low, R.id.weather_widget_d4_high),
        )

        private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun placeIdFor(context: Context, widgetId: Int): Int? =
            prefs(context).getInt("$KEY_PREFIX$widgetId", -1).takeIf { it >= 0 }

        fun setPlaceId(context: Context, widgetId: Int, placeId: Int?) {
            prefs(context).edit().apply {
                if (placeId == null) remove("$KEY_PREFIX$widgetId") else putInt("$KEY_PREFIX$widgetId", placeId)
            }.commit()
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, WeatherWidgetProvider::class.java))
                .forEach { update(context, manager, it) }
        }


        private fun background(theme: String): Int = when (theme) {
            "night" -> R.drawable.weather_widget_bg_night
            "gray" -> R.drawable.weather_widget_bg_gray
            "storm" -> R.drawable.weather_widget_bg_storm
            else -> R.drawable.weather_widget_bg_day
        }

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val snapshot = WeatherFiles.read(context)
            val chosen = placeIdFor(context, widgetId) ?: snapshot.defaultId
            val place = snapshot.places.firstOrNull { it.id == chosen } ?: snapshot.places.firstOrNull()
            val views = RemoteViews(context.packageName, R.layout.weather_widget)
            val options = manager.getAppWidgetOptions(widgetId)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110)
            val showHours = place != null && width >= 220 && height >= 150 && place.hours.isNotEmpty()
            val showDays = place != null && width >= 220 && height >= 290 && place.days.isNotEmpty()
            val compact = width < 180

            views.setOnClickPendingIntent(
                R.id.weather_widget_root,
                WeatherIntents.activity(context, widgetId, WeatherIntents.open(context, place?.id)),
            )
            views.setViewVisibility(R.id.weather_widget_empty, if (place == null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.weather_widget_header, if (place == null) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.weather_widget_hours, if (showHours) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.weather_widget_days, if (showDays) View.VISIBLE else View.GONE)
            if (place == null) {
                views.setViewVisibility(R.id.weather_widget_warning, View.GONE)
                views.setTextViewText(R.id.weather_widget_updated, "")
                manager.updateAppWidget(widgetId, views)
                return
            }

            views.setInt(R.id.weather_widget_root, "setBackgroundResource", background(place.theme))
            views.setTextViewText(R.id.weather_widget_place, place.name)
            views.setTextViewText(R.id.weather_widget_temp, place.temp)
            views.setTextViewText(R.id.weather_widget_condition, place.condition)
            views.setTextViewText(R.id.weather_widget_range, place.range)
            views.setImageViewResource(R.id.weather_widget_icon, WeatherIcons.forKey(place.icon))
            views.setContentDescription(R.id.weather_widget_icon, place.condition)
            views.setViewVisibility(R.id.weather_widget_condition, if (compact) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.weather_widget_updated, if (compact) "" else place.updated)

            val warning = place.warning
            if (warning != null && height >= 150) {
                views.setViewVisibility(R.id.weather_widget_warning, View.VISIBLE)
                views.setTextViewText(R.id.weather_widget_warning, warning.text)
                views.setTextViewCompoundDrawablesRelative(R.id.weather_widget_warning, R.drawable.weather_widget_dot, 0, 0, 0)
                views.setInt(R.id.weather_widget_warning, "setBackgroundColor", (warning.color and 0x00FFFFFF) or 0x66000000)
            } else {
                views.setViewVisibility(R.id.weather_widget_warning, View.GONE)
            }

            if (showHours) {
                hourIds.forEachIndexed { i, ids ->
                    val hour = place.hours.getOrNull(i)
                    views.setTextViewText(ids[0], hour?.time ?: "")
                    views.setTextViewText(ids[2], hour?.temp ?: "")
                    if (hour != null) views.setImageViewResource(ids[1], WeatherIcons.forKey(hour.icon))
                    views.setViewVisibility(ids[1], if (hour == null) View.INVISIBLE else View.VISIBLE)
                }
            }
            if (showDays) {
                // Fit as many day rows as the height allows, about 30dp each.
                val rows = ((height - 260) / 30 + 1).coerceIn(1, dayIds.size)
                dayIds.forEachIndexed { i, ids ->
                    val day = place.days.getOrNull(i)
                    if (day == null || i >= rows) {
                        views.setViewVisibility(ids[0], View.GONE)
                        return@forEachIndexed
                    }
                    views.setViewVisibility(ids[0], View.VISIBLE)
                    views.setTextViewText(ids[1], day.label)
                    views.setImageViewResource(ids[2], WeatherIcons.forKey(day.icon))
                    views.setTextViewText(ids[3], day.low)
                    views.setTextViewText(ids[4], day.high)
                }
            }
            manager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, widgetId: Int, newOptions: Bundle) {
        update(context, manager, widgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { setPlaceId(context, it, null) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_LOCALE_CHANGED) refreshAll(context)
    }
}

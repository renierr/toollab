package de.renier.tool_lab.weather

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import de.renier.tool_lab.R

/** Lets the user pick the place a widget shows; without a choice it follows the default place. */
class WeatherWidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        setResult(RESULT_CANCELED, resultIntent())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setTitle(R.string.weather_widget_config_title)

        val places = WeatherFiles.read(this).places
        if (places.isEmpty()) {
            setContentView(
                TextView(this).apply {
                    text = getString(R.string.weather_widget_no_data)
                    gravity = Gravity.CENTER
                    setPadding(dp(24f), dp(32f), dp(24f), dp(32f))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setOnClickListener { finishWith(null) }
                },
            )
            return
        }
        val current = WeatherWidgetProvider.placeIdFor(this, widgetId)
        val listView = ListView(this).apply {
            adapter = object : ArrayAdapter<WeatherWidgetPlace>(
                this@WeatherWidgetConfigActivity,
                android.R.layout.simple_list_item_1,
                places,
            ) {
                override fun getView(position: Int, convertView: View?, parent: ViewGroup): View =
                    (super.getView(position, convertView, parent) as TextView).apply {
                        val place = places[position]
                        text = if (place.temp.isEmpty()) place.name else "${place.name}  ·  ${place.temp}"
                        setPadding(dp(20f), dp(14f), dp(20f), dp(14f))
                        setTypeface(null, if (place.id == current) Typeface.BOLD else Typeface.NORMAL)
                    }
            }
            setOnItemClickListener { _, _, position, _ -> finishWith(places[position].id) }
        }
        setContentView(listView)
    }

    private fun finishWith(placeId: Int?) {
        if (placeId != null) WeatherWidgetProvider.setPlaceId(this, widgetId, placeId)
        WeatherWidgetProvider.update(this, AppWidgetManager.getInstance(this), widgetId)
        setResult(RESULT_OK, resultIntent())
        finish()
    }

    private fun resultIntent() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

    private fun dp(value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()
}

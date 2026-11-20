package de.renier.tool_lab.weather

import android.content.Context
import org.json.JSONObject
import java.io.File

data class WeatherWidgetHour(val time: String, val icon: String, val temp: String)

data class WeatherWidgetDay(val label: String, val icon: String, val high: String, val low: String)

data class WeatherWidgetWarning(val text: String, val color: Int)

/** One place as Dart prepared it: every text is already localized and in the user's units. */
data class WeatherWidgetPlace(
    val id: Int,
    val name: String,
    val temp: String,
    val condition: String,
    val icon: String,
    val theme: String,
    val range: String,
    val updated: String,
    val details: List<String>,
    val hours: List<WeatherWidgetHour>,
    val days: List<WeatherWidgetDay>,
    val warning: WeatherWidgetWarning?,
)

/** Reads the snapshot `WeatherPublisher` writes to `files/weather/widget.json`. */
object WeatherFiles {
    private const val WIDGET = "widget.json"

    fun dir(context: Context): File = File(context.filesDir, "weather").apply { mkdirs() }

    data class Snapshot(val defaultId: Int?, val places: List<WeatherWidgetPlace>)

    fun read(context: Context): Snapshot {
        val file = File(dir(context), WIDGET)
        if (!file.exists()) return Snapshot(null, emptyList())
        return try {
            val json = JSONObject(file.readText())
            val places = json.optJSONArray("places") ?: return Snapshot(null, emptyList())
            Snapshot(
                defaultId = json.optInt("defaultId", -1).takeIf { it >= 0 },
                places = (0 until places.length()).mapNotNull { i -> place(places.optJSONObject(i)) },
            )
        } catch (e: Exception) {
            android.util.Log.w("WeatherFiles", "widget.json unreadable: ${e.message}")
            Snapshot(null, emptyList())
        }
    }

    private fun place(json: JSONObject?): WeatherWidgetPlace? {
        if (json == null || !json.has("id")) return null
        val hours = json.optJSONArray("hours")
        val days = json.optJSONArray("days")
        val warning = json.optJSONObject("warning")
        val details = json.optJSONArray("details")
        return WeatherWidgetPlace(
            id = json.getInt("id"),
            name = json.optString("name"),
            temp = json.optString("temp"),
            condition = json.optString("condition"),
            icon = json.optString("icon"),
            theme = json.optString("theme", "day"),
            range = json.optString("range"),
            updated = json.optString("updated"),
            details = (0 until (details?.length() ?: 0)).map { details!!.optString(it) }.filter { it.isNotEmpty() },
            hours = (0 until (hours?.length() ?: 0)).mapNotNull { i ->
                hours!!.optJSONObject(i)?.let {
                    WeatherWidgetHour(it.optString("time"), it.optString("icon"), it.optString("temp"))
                }
            },
            days = (0 until (days?.length() ?: 0)).mapNotNull { i ->
                days!!.optJSONObject(i)?.let {
                    WeatherWidgetDay(it.optString("label"), it.optString("icon"), it.optString("high"), it.optString("low"))
                }
            },
            warning = warning?.let {
                WeatherWidgetWarning(it.optString("text"), it.optLong("color", 0xFFFFA000L).toInt())
            },
        )
    }
}

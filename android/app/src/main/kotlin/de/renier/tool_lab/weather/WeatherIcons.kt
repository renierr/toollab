package de.renier.tool_lab.weather

import de.renier.tool_lab.R

/**
 * Direct references, so resource shrinking keeps every icon; a lookup by name
 * would let a release build drop them. Keys match `WeatherPublisher.iconKey`.
 */
object WeatherIcons {
    private val byKey = mapOf(
        "clear_d" to R.drawable.weather_icon_clear_d,
        "clear_n" to R.drawable.weather_icon_clear_n,
        "cloudy_d" to R.drawable.weather_icon_cloudy_d,
        "cloudy_n" to R.drawable.weather_icon_cloudy_n,
        "drizzle_d" to R.drawable.weather_icon_drizzle_d,
        "drizzle_n" to R.drawable.weather_icon_drizzle_n,
        "fog_d" to R.drawable.weather_icon_fog_d,
        "fog_n" to R.drawable.weather_icon_fog_n,
        "freezing_drizzle_d" to R.drawable.weather_icon_freezing_drizzle_d,
        "freezing_drizzle_n" to R.drawable.weather_icon_freezing_drizzle_n,
        "freezing_rain_d" to R.drawable.weather_icon_freezing_rain_d,
        "freezing_rain_n" to R.drawable.weather_icon_freezing_rain_n,
        "hail_d" to R.drawable.weather_icon_hail_d,
        "hail_n" to R.drawable.weather_icon_hail_n,
        "heavy_rain_d" to R.drawable.weather_icon_heavy_rain_d,
        "heavy_rain_n" to R.drawable.weather_icon_heavy_rain_n,
        "heavy_snow_d" to R.drawable.weather_icon_heavy_snow_d,
        "heavy_snow_n" to R.drawable.weather_icon_heavy_snow_n,
        "light_rain_d" to R.drawable.weather_icon_light_rain_d,
        "light_rain_n" to R.drawable.weather_icon_light_rain_n,
        "light_snow_d" to R.drawable.weather_icon_light_snow_d,
        "light_snow_n" to R.drawable.weather_icon_light_snow_n,
        "mostly_clear_d" to R.drawable.weather_icon_mostly_clear_d,
        "mostly_clear_n" to R.drawable.weather_icon_mostly_clear_n,
        "overcast_d" to R.drawable.weather_icon_overcast_d,
        "overcast_n" to R.drawable.weather_icon_overcast_n,
        "partly_cloudy_d" to R.drawable.weather_icon_partly_cloudy_d,
        "partly_cloudy_n" to R.drawable.weather_icon_partly_cloudy_n,
        "rain_d" to R.drawable.weather_icon_rain_d,
        "rain_n" to R.drawable.weather_icon_rain_n,
        "rain_shower_d" to R.drawable.weather_icon_rain_shower_d,
        "rain_shower_n" to R.drawable.weather_icon_rain_shower_n,
        "sleet_d" to R.drawable.weather_icon_sleet_d,
        "sleet_n" to R.drawable.weather_icon_sleet_n,
        "sleet_shower_d" to R.drawable.weather_icon_sleet_shower_d,
        "sleet_shower_n" to R.drawable.weather_icon_sleet_shower_n,
        "snow_d" to R.drawable.weather_icon_snow_d,
        "snow_n" to R.drawable.weather_icon_snow_n,
        "snow_shower_d" to R.drawable.weather_icon_snow_shower_d,
        "snow_shower_n" to R.drawable.weather_icon_snow_shower_n,
        "thunderstorm_d" to R.drawable.weather_icon_thunderstorm_d,
        "thunderstorm_n" to R.drawable.weather_icon_thunderstorm_n,
    )

    fun forKey(key: String): Int = byKey[key] ?: R.drawable.weather_icon_partly_cloudy_d
}

import 'hourly_forecast.dart';
import 'weather_condition.dart';

/// One measured hour from a DWD POI station, in °C, hPa, m/s, mm, %, metres.
class WeatherObservation {
  const WeatherObservation({
    required this.time,
    this.temperature,
    this.dewPoint,
    this.humidity,
    this.pressure,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.precipitation1h,
    this.precipitation24h,
    this.cloudCover,
    this.visibility,
    this.snowDepth,
    this.sunshineMinutes,
    this.presentWeather,
  });

  final DateTime time;
  final double? temperature;
  final double? dewPoint;
  final double? humidity;
  final double? pressure;
  final double? windSpeed;
  final double? windDirection;
  final double? windGust;
  final double? precipitation1h;
  final double? precipitation24h;
  final double? cloudCover;
  final double? visibility;
  final double? snowDepth;
  final double? sunshineMinutes;
  final int? presentWeather;

  WeatherCondition? get condition =>
      WeatherCondition.fromDwdCode(presentWeather) ??
      (cloudCover == null ? null : WeatherCondition.fromCloudCover(cloudCover));

  double? get feelsLike =>
      apparentTemperature(temperature, humidity, windSpeed);
}

class ObservationSeries {
  const ObservationSeries({required this.stationId, required this.rows});

  final String stationId;

  /// Newest first, as served by DWD.
  final List<WeatherObservation> rows;

  WeatherObservation? get latest => rows.isEmpty ? null : rows.first;
}

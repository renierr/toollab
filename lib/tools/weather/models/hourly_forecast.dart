import 'dart:math' as math;

import 'weather_condition.dart';

/// One forecast hour in SI-ish units: °C, hPa, m/s, mm, %, minutes, metres.
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    this.temperature,
    this.dewPoint,
    this.pressure,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.cloudCover,
    this.precipitation,
    this.precipitationProbability,
    this.sunshineMinutes,
    this.visibility,
    this.weatherCode,
  });

  final DateTime time;
  final double? temperature;
  final double? dewPoint;
  final double? pressure;
  final double? windSpeed;
  final double? windDirection;
  final double? windGust;
  final double? cloudCover;
  final double? precipitation;
  final double? precipitationProbability;
  final double? sunshineMinutes;
  final double? visibility;
  final int? weatherCode;

  WeatherCondition get condition =>
      WeatherCondition.fromWw(weatherCode, cloudCover: cloudCover);

  double? get humidity => relativeHumidity(temperature, dewPoint);
}

/// Magnus formula.
double? relativeHumidity(double? temperature, double? dewPoint) {
  if (temperature == null || dewPoint == null) return null;
  const a = 17.625;
  const b = 243.04;
  final rh =
      100 *
      math.exp(a * dewPoint / (b + dewPoint)) /
      math.exp(a * temperature / (b + temperature));
  return rh.clamp(0, 100).toDouble();
}

/// Steadman apparent temperature without radiation; wind in m/s.
double? apparentTemperature(
  double? temperature,
  double? humidity,
  double? wind,
) {
  if (temperature == null) return null;
  final w = wind ?? 0;
  if (temperature <= 10 && w > 1.34) {
    final v = math.pow(w * 3.6, 0.16);
    return 13.12 + 0.6215 * temperature - 11.37 * v + 0.3965 * temperature * v;
  }
  if (humidity == null) return temperature;
  final e =
      humidity /
      100 *
      6.105 *
      math.exp(17.27 * temperature / (237.7 + temperature));
  return temperature + 0.33 * e - 0.70 * w - 4.0;
}

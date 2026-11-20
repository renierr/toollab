import 'hourly_forecast.dart';
import 'weather_condition.dart';
import 'weather_observation.dart';
import 'weather_snapshot.dart';

enum WeatherHistorySource { measured, forecast }

/// One recorded hour of a place, in °C, hPa, m/s, mm, %, minutes.
class WeatherHistoryEntry {
  const WeatherHistoryEntry({
    required this.locationId,
    required this.hour,
    required this.source,
    this.temperature,
    this.dewPoint,
    this.pressure,
    this.windSpeed,
    this.windGust,
    this.windDirection,
    this.precipitation,
    this.cloudCover,
    this.sunshineMinutes,
    this.condition,
  });

  factory WeatherHistoryEntry.fromMap(Map<String, Object?> map) {
    double? d(String key) => (map[key] as num?)?.toDouble();
    return WeatherHistoryEntry(
      locationId: map['location_id']! as int,
      hour: DateTime.fromMillisecondsSinceEpoch(
        (map['hour']! as int) * 1000,
        isUtc: true,
      ),
      source: WeatherHistorySource.values[map['source']! as int],
      temperature: d('temperature'),
      dewPoint: d('dew_point'),
      pressure: d('pressure'),
      windSpeed: d('wind_speed'),
      windGust: d('wind_gust'),
      windDirection: d('wind_direction'),
      precipitation: d('precipitation'),
      cloudCover: d('cloud_cover'),
      sunshineMinutes: d('sunshine'),
      condition: WeatherCondition.values.asNameMap()[map['condition']],
    );
  }

  final int locationId;

  /// Start of the hour, UTC.
  final DateTime hour;
  final WeatherHistorySource source;
  final double? temperature;
  final double? dewPoint;
  final double? pressure;
  final double? windSpeed;
  final double? windGust;
  final double? windDirection;
  final double? precipitation;
  final double? cloudCover;
  final double? sunshineMinutes;
  final WeatherCondition? condition;

  bool get isMeasured => source == WeatherHistorySource.measured;

  Map<String, Object?> toMap() => {
    'location_id': locationId,
    'hour': hour.millisecondsSinceEpoch ~/ 1000,
    'source': source.index,
    'temperature': temperature,
    'dew_point': dewPoint,
    'pressure': pressure,
    'wind_speed': windSpeed,
    'wind_gust': windGust,
    'wind_direction': windDirection,
    'precipitation': precipitation,
    'cloud_cover': cloudCover,
    'sunshine': sunshineMinutes,
    'condition': condition?.name,
  };

  /// For the charts and readouts the forecast uses.
  HourlyForecast toHourly() => HourlyForecast(
    time: hour,
    temperature: temperature,
    dewPoint: dewPoint,
    pressure: pressure,
    windSpeed: windSpeed,
    windDirection: windDirection,
    windGust: windGust,
    cloudCover: cloudCover,
    precipitation: precipitation,
    sunshineMinutes: sunshineMinutes,
    fixedCondition: condition,
  );

  static DateTime hourOf(DateTime t) {
    final u = t.toUtc();
    return DateTime.utc(u.year, u.month, u.day, u.hour);
  }

  /// Measured hours from the station and past forecast hours as a fallback.
  static List<WeatherHistoryEntry> fromSnapshot(
    int locationId,
    WeatherSnapshot snapshot,
    DateTime now,
  ) {
    final measured = <WeatherHistoryEntry>[
      for (final o
          in snapshot.observations?.rows ?? const <WeatherObservation>[])
        if (o.time.toUtc().minute == 0 && !o.time.isAfter(now))
          WeatherHistoryEntry(
            locationId: locationId,
            hour: hourOf(o.time),
            source: WeatherHistorySource.measured,
            temperature: o.temperature,
            dewPoint: o.dewPoint,
            pressure: o.pressure,
            windSpeed: o.windSpeed,
            windGust: o.windGust,
            windDirection: o.windDirection,
            precipitation: o.precipitation1h,
            cloudCover: o.cloudCover,
            sunshineMinutes: o.sunshineMinutes,
            condition: o.condition,
          ),
    ];
    final forecast = <WeatherHistoryEntry>[
      for (final h in snapshot.forecast?.hours ?? const <HourlyForecast>[])
        if (!h.time.isAfter(now))
          WeatherHistoryEntry(
            locationId: locationId,
            hour: hourOf(h.time),
            source: WeatherHistorySource.forecast,
            temperature: h.temperature,
            dewPoint: h.dewPoint,
            pressure: h.pressure,
            windSpeed: h.windSpeed,
            windGust: h.windGust,
            windDirection: h.windDirection,
            precipitation: h.precipitation,
            cloudCover: h.cloudCover,
            sunshineMinutes: h.sunshineMinutes,
            condition: h.condition,
          ),
    ];
    return [...measured, ...forecast];
  }
}

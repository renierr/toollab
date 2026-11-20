import '../api/station_catalog.dart';
import '../api/weather_http.dart';
import 'astronomy.dart';
import 'hourly_forecast.dart';
import 'mosmix_forecast.dart';
import 'station_overview.dart';
import 'weather_condition.dart';
import 'weather_location.dart';
import 'weather_observation.dart';
import 'weather_warning.dart';

/// Everything known about one location after a refresh.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.location,
    required this.fetchedAt,
    this.forecastStation,
    this.observationStation,
    this.forecast,
    this.observations,
    this.overview,
    this.isStale = false,
    this.error,
  });

  /// A measurement older than this no longer counts as "now".
  static const Duration observationMaxAge = Duration(minutes: 150);

  final WeatherLocation location;
  final DateTime fetchedAt;
  final StationMatch? forecastStation;
  final StationMatch? observationStation;
  final MosmixForecast? forecast;
  final ObservationSeries? observations;
  final StationOverview? overview;

  /// Some data came from the cache because the network failed.
  final bool isStale;
  final WeatherError? error;

  bool get hasData => forecast != null || observations?.latest != null;

  WeatherObservation? liveObservation(DateTime now) {
    final latest = observations?.latest;
    if (latest == null || now.difference(latest.time) > observationMaxAge) {
      return null;
    }
    return latest;
  }

  HourlyForecast? currentHour(DateTime now) {
    final hours = forecast?.hours;
    if (hours == null || hours.isEmpty) return null;
    HourlyForecast? best;
    for (final h in hours) {
      if (h.time.isAfter(now.add(const Duration(minutes: 30)))) break;
      best = h;
    }
    return best ?? hours.first;
  }

  CurrentConditions? current(DateTime now) {
    final hour = currentHour(now);
    final obs = liveObservation(now);
    if (hour == null && obs == null) return null;
    final temperature = obs?.temperature ?? hour?.temperature;
    final humidity = obs?.humidity ?? hour?.humidity;
    final wind = obs?.windSpeed ?? hour?.windSpeed;
    return CurrentConditions(
      measuredAt: obs?.time,
      temperature: temperature,
      feelsLike: apparentTemperature(temperature, humidity, wind),
      humidity: humidity,
      dewPoint: obs?.dewPoint ?? hour?.dewPoint,
      pressure: obs?.pressure ?? hour?.pressure,
      windSpeed: wind,
      windDirection: obs?.windDirection ?? hour?.windDirection,
      windGust: obs?.windGust ?? hour?.windGust,
      cloudCover: obs?.cloudCover ?? hour?.cloudCover,
      visibility: obs?.visibility ?? hour?.visibility,
      precipitation: obs?.precipitation1h ?? hour?.precipitation,
      condition:
          obs?.condition ?? hour?.condition ?? WeatherCondition.partlyCloudy,
    );
  }

  /// DWD day summary when present, otherwise computed for the location.
  SunTimes sunTimes(DateTime day) {
    final local = day.toLocal();
    final dwd = overview?.dayOf(local);
    if (dwd?.sunrise != null && dwd?.sunset != null) {
      return SunTimes(dwd!.sunrise, dwd.sunset);
    }
    return SunTimes.of(local, location.latitude, location.longitude);
  }

  bool isDayAt(DateTime time) => sunTimes(time).isDayAt(time);

  List<WeatherWarning> warnings(DateTime now) => [
    for (final w in overview?.warnings ?? const <WeatherWarning>[])
      if (w.end == null || w.end!.isAfter(now)) w,
  ];
}

class CurrentConditions {
  const CurrentConditions({
    this.measuredAt,
    this.temperature,
    this.feelsLike,
    this.humidity,
    this.dewPoint,
    this.pressure,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.cloudCover,
    this.visibility,
    this.precipitation,
    required this.condition,
  });

  /// Set when the values come from a station measurement, not the forecast.
  final DateTime? measuredAt;
  final double? temperature;
  final double? feelsLike;
  final double? humidity;
  final double? dewPoint;
  final double? pressure;
  final double? windSpeed;
  final double? windDirection;
  final double? windGust;
  final double? cloudCover;
  final double? visibility;
  final double? precipitation;
  final WeatherCondition condition;

  bool get isMeasured => measuredAt != null;
}

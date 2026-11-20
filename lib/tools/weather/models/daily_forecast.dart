import 'hourly_forecast.dart';
import 'weather_condition.dart';

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.hours,
    this.minTemperature,
    this.maxTemperature,
    this.precipitationSum,
    this.precipitationProbability,
    this.maxWindGust,
    this.meanWindSpeed,
    this.sunshineHours,
    required this.condition,
  });

  /// Groups hours by local calendar day; [hours] must be sorted by time.
  static List<DailyForecast> fromHours(List<HourlyForecast> hours) {
    final byDay = <DateTime, List<HourlyForecast>>{};
    for (final h in hours) {
      final local = h.time.toLocal();
      byDay
          .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
          .add(h);
    }
    return [
      for (final entry in byDay.entries)
        if (entry.value.length >= 6) _aggregate(entry.key, entry.value),
    ];
  }

  static DailyForecast _aggregate(DateTime date, List<HourlyForecast> hours) {
    List<double> values(double? Function(HourlyForecast h) pick) => [
      for (final h in hours) ?pick(h),
    ];
    double? maxOf(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
    double? minOf(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
    double? sumOf(List<double> v) =>
        v.isEmpty ? null : v.fold<double>(0, (a, b) => a + b);

    final temps = values((h) => h.temperature);
    final winds = values((h) => h.windSpeed);
    final sun = sumOf(values((h) => h.sunshineMinutes));
    return DailyForecast(
      date: date,
      hours: hours,
      minTemperature: minOf(temps),
      maxTemperature: maxOf(temps),
      precipitationSum: sumOf(values((h) => h.precipitation)),
      precipitationProbability: maxOf(
        values((h) => h.precipitationProbability),
      ),
      maxWindGust: maxOf(values((h) => h.windGust)),
      meanWindSpeed: winds.isEmpty ? null : sumOf(winds)! / winds.length,
      sunshineHours: sun == null ? null : sun / 60,
      condition: _dominantCondition(hours),
    );
  }

  /// Daytime precipitation wins when it lasts at least two hours, otherwise
  /// the mean daytime cloud cover decides.
  static WeatherCondition _dominantCondition(List<HourlyForecast> hours) {
    final daytime = hours.where((h) {
      final hour = h.time.toLocal().hour;
      return hour >= 7 && hour <= 19;
    }).toList();
    final pool = daytime.isEmpty ? hours : daytime;
    final counts = <WeatherCondition, int>{};
    for (final h in pool) {
      final c = h.condition;
      if (c.isPrecipitation || c == WeatherCondition.fog) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    if (counts.isNotEmpty) {
      final top = counts.entries.reduce((a, b) {
        if (a.value != b.value) return a.value > b.value ? a : b;
        return a.key.index >= b.key.index ? a : b;
      });
      if (top.value >= 2) return top.key;
    }
    final clouds = [for (final h in pool) ?h.cloudCover];
    return WeatherCondition.fromCloudCover(
      clouds.isEmpty ? null : clouds.reduce((a, b) => a + b) / clouds.length,
    );
  }

  final DateTime date;
  final List<HourlyForecast> hours;
  final double? minTemperature;
  final double? maxTemperature;
  final double? precipitationSum;
  final double? precipitationProbability;
  final double? maxWindGust;
  final double? meanWindSpeed;
  final double? sunshineHours;
  final WeatherCondition condition;
}

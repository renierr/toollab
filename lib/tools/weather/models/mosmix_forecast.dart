import 'daily_forecast.dart';
import 'hourly_forecast.dart';

class MosmixForecast {
  MosmixForecast({
    required this.stationId,
    required this.issueTime,
    required this.hours,
  }) : days = DailyForecast.fromHours(hours);

  final String stationId;
  final DateTime issueTime;
  final List<HourlyForecast> hours;
  final List<DailyForecast> days;

  List<HourlyForecast> upcoming(DateTime now, {int count = 48}) {
    final start = now.subtract(const Duration(hours: 1));
    return hours.where((h) => h.time.isAfter(start)).take(count).toList();
  }
}

import 'day_astronomy.dart';
import 'weather_warning.dart';

class StationOverview {
  const StationOverview({required this.days, required this.warnings});

  final List<DayAstronomy> days;
  final List<WeatherWarning> warnings;

  DayAstronomy? dayOf(DateTime date) {
    for (final d in days) {
      if (d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day) {
        return d;
      }
    }
    return null;
  }
}

import 'models/weather_history_entry.dart';
import 'weather_db_helper.dart';

/// Where the screens read recorded hours from; widget tests swap in memory,
/// since database I/O never completes in fake time.
class WeatherHistoryStore {
  const WeatherHistoryStore();

  /// Hours of a place in `[from, to)`, oldest first.
  Future<List<WeatherHistoryEntry>> hours(
    int locationId,
    DateTime from,
    DateTime to,
  ) => WeatherDbHelper.instance.getHistory(locationId, from, to);

  Future<int> count() => WeatherDbHelper.instance.historyCount();

  Future<void> clear() => WeatherDbHelper.instance.clearHistory();
}

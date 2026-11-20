// A hang should fail fast instead of after the 10-minute default.
@Timeout(Duration(minutes: 1))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/weather/models/weather_condition.dart';
import 'package:tool_lab/tools/weather/models/weather_history_entry.dart';
import 'package:tool_lab/tools/weather/models/weather_history_summary.dart';
import 'package:tool_lab/tools/weather/models/weather_location.dart';
import 'package:tool_lab/tools/weather/weather_db_helper.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';

WeatherHistoryEntry _hour(
  DateTime local, {
  int location = 1,
  double? temp,
  double rain = 0,
  WeatherHistorySource source = WeatherHistorySource.measured,
  WeatherCondition condition = WeatherCondition.cloudy,
}) => WeatherHistoryEntry(
  locationId: location,
  hour: local.toUtc(),
  source: source,
  temperature: temp,
  precipitation: rain,
  windGust: 10,
  condition: condition,
);

void main() {
  group('HistoryRange', () {
    test('weeks start on Monday and shift by whole periods', () {
      final week = HistoryRange.containing(
        HistoryPeriod.week,
        DateTime(2026, 11, 20, 15),
      );
      expect(week.start, DateTime(2026, 11, 16));
      expect(week.end, DateTime(2026, 11, 23));
      expect(week.shift(-1).start, DateTime(2026, 11, 9));
      final month = HistoryRange.containing(
        HistoryPeriod.month,
        DateTime(2026, 1, 31),
      );
      expect(month.shift(1).start, DateTime(2026, 2));
      expect(month.shift(-1).start, DateTime(2025, 12));
      expect(month.previousYear().start, DateTime(2025, 1));
    });

    test('elapsed hours stop at now', () {
      final day = HistoryRange.containing(
        HistoryPeriod.day,
        DateTime(2026, 11, 20),
      );
      expect(day.elapsedHours(DateTime(2026, 11, 20, 6)), 6);
      expect(day.elapsedHours(DateTime(2026, 11, 25)), 24);
      expect(day.elapsedHours(DateTime(2026, 11, 19)), 0);
    });

    test('the last days span a year boundary', () {
      final r = HistoryRange.lastDays(7, DateTime(2027, 1, 3, 10));
      expect(r.start, DateTime(2026, 12, 28));
      expect(r.contains(DateTime(2026, 12, 31, 12)), isTrue);
    });
  });

  group('HistorySummary', () {
    final range = HistoryRange.containing(
      HistoryPeriod.week,
      DateTime(2026, 11, 18),
    );
    final entries = [
      for (var h = 0; h < 24; h++)
        _hour(
          DateTime(2026, 11, 16, h),
          temp: 2.0 + h / 2,
          rain: h < 3 ? 1 : 0,
        ),
      for (var h = 0; h < 24; h++)
        _hour(
          DateTime(2026, 11, 17, h),
          temp: -1.0 + h / 4,
          condition: WeatherCondition.clear,
        ),
      _hour(DateTime(2026, 11, 30), temp: 40),
    ];
    final summary = HistorySummary.of(entries, range);

    test('ignores hours outside the period and groups by day', () {
      expect(summary.entries, hasLength(48));
      expect(summary.days, hasLength(2));
      expect(summary.buckets.first.start, DateTime(2026, 11, 16));
    });

    test('finds extremes, sums and rain days', () {
      expect(summary.coldestHour!.temperature, -1);
      expect(summary.warmestHour!.temperature, 13.5);
      expect(summary.warmestDay!.start, DateTime(2026, 11, 16));
      expect(summary.coldestDay!.start, DateTime(2026, 11, 17));
      expect(summary.total.precipitation, 3);
      expect(summary.rainDays, 1);
      expect(summary.days.last.condition, WeatherCondition.clear);
    });

    test('coverage compares recorded with elapsed hours', () {
      expect(summary.coverage(DateTime(2026, 11, 18)), 1);
      expect(summary.coverage(DateTime(2026, 11, 20)), closeTo(48 / 96, .001));
    });

    test('a year is bucketed by month', () {
      final year = HistorySummary.of(
        entries,
        HistoryRange.containing(HistoryPeriod.year, DateTime(2026, 6)),
      );
      expect(year.buckets.map((b) => b.start), [DateTime(2026, 11)]);
      expect(year.days, hasLength(3));
    });
  });

  group('history table', () {
    final db = WeatherDbHelper.instance;
    const place = WeatherLocation(
      name: 'Eschborn',
      latitude: 50.15,
      longitude: 8.56,
    );

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
      db.reset();
    });

    tearDownAll(() async {
      await DatabaseService.instance.close();
    });

    test('measurements replace forecasts, never the other way round', () async {
      final saved = await db.saveLocation(place);
      final t = DateTime(2026, 11, 20, 10);
      await db.recordHistory([
        _hour(
          t,
          location: saved.id!,
          temp: 5,
          source: WeatherHistorySource.forecast,
        ),
      ]);
      await db.recordHistory([_hour(t, location: saved.id!, temp: 7)]);
      await db.recordHistory([
        _hour(
          t,
          location: saved.id!,
          temp: 9,
          source: WeatherHistorySource.forecast,
        ),
      ]);
      final rows = await db.getHistory(
        saved.id!,
        t,
        t.add(const Duration(hours: 1)),
      );
      expect(rows.single.temperature, 7);
      expect(rows.single.isMeasured, isTrue);
      expect(rows.single.condition, WeatherCondition.cloudy);
    });

    test('prune drops old hours and those of deleted places', () async {
      final a = await db.saveLocation(place);
      final b = await db.saveLocation(place);
      await db.clearHistory();
      await db.recordHistory([
        _hour(DateTime(2025, 1, 1), location: a.id!, temp: 1),
        _hour(DateTime(2026, 11, 1), location: a.id!, temp: 2),
        _hour(DateTime(2026, 11, 1), location: b.id!, temp: 3),
      ]);
      await db.deleteLocation(b.id!);
      // An undo restores the place with its history.
      await db.restoreLocation(b);
      await db.pruneHistory(null);
      expect(await db.historyCount(), 3);

      await db.deleteLocation(b.id!);
      final cutoff = const WeatherSettings(
        historyMonths: 12,
      ).historyCutoff(DateTime(2026, 11, 20))!;
      await db.pruneHistory(cutoff);
      expect(await db.historyCount(), 1);
      expect(
        const WeatherSettings(historyMonths: 0).historyCutoff(DateTime.now()),
        isNull,
      );
    });
  });
}

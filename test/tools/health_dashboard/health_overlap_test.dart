import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_metric_catalog.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_models.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_overlap.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_rows.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_schema.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_store.dart';

void main() {
  const minute = 60000;

  group('HealthOverlap.distinct', () {
    test('drops a shifted re-upload, keeps adjacent buckets', () {
      final kept = HealthOverlap.distinct([
        (t0: 0, t1: 30 * minute, v: 5.0),
        (t0: 5000, t1: 30 * minute + 2000, v: 5.01),
        (t0: 30 * minute, t1: 40 * minute, v: 1.0),
      ]);
      expect(kept.map((r) => r.v), [5.0, 1.0]);
    });

    test('a whole-workout record swallows its buckets', () {
      final kept = HealthOverlap.distinct([
        for (var i = 0; i < 3; i++)
          (t0: i * 10 * minute, t1: (i + 1) * 10 * minute, v: 1.0),
        (t0: 0, t1: 30 * minute, v: 3.0),
      ]);
      expect(kept.map((r) => r.v), [3.0]);
    });

    test('a small overlap at the edge still counts both', () {
      final kept = HealthOverlap.distinct([
        (t0: 0, t1: 10 * minute, v: 1.0),
        (t0: 9 * minute, t1: 20 * minute, v: 1.0),
      ]);
      expect(kept, hasLength(2));
    });
  });

  test('distinctSessions keeps different activities and other writers', () {
    HealthSession run(int id, int t0, int t1, {String pkg = 'w', String? a}) =>
        HealthSession(
          id: id,
          kind: HealthSchema.sessionKindExercise,
          t0: t0,
          t1: t1,
          package: pkg,
          activity: a ?? 'running',
        );
    final kept = HealthOverlap.distinctSessions([
      run(1, 0, 30 * minute),
      run(2, 5000, 30 * minute + 2000),
      run(3, 0, 30 * minute, a: 'walking'),
      run(4, 0, 30 * minute, pkg: 'other'),
    ]);
    expect(kept.map((s) => s.id), [1, 3, 4]);
  });

  group('store', () {
    final day = DateTime(2025, 3, 10).millisecondsSinceEpoch;
    final run = day + 10 * 60 * minute;
    const watch = 'com.example.watch';

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    });

    tearDownAll(() async {
      await DatabaseService.instance.close();
    });

    HealthMappedRecord session(String origin, int shift) => HealthMappedRecord(
      package: watch,
      intervals: [
        HealthIntervalRow(
          metric: HealthMetrics.distance,
          t0: run + shift,
          t1: run + 30 * minute + shift,
          v: 5 + shift / 1e6,
        ),
      ],
      session: HealthSessionRow(
        kind: HealthSchema.sessionKindExercise,
        activity: 'running',
        t0: run + shift,
        t1: run + 30 * minute + shift,
        origin: origin,
      ),
    );

    test('a watch writing a run twice counts it once', () async {
      final store = HealthStore.instance;
      await store.writeRecords([
        session('a', 0),
        session('b', 5000),
        HealthMappedRecord(
          package: watch,
          intervals: [
            HealthIntervalRow(
              metric: HealthMetrics.distance,
              t0: day + 15 * 60 * minute,
              t1: day + 15 * 60 * minute + 10 * minute,
              v: 1,
            ),
            for (var i = 0; i < 2; i++)
              HealthIntervalRow(
                metric: HealthMetrics.hydration,
                t0: day + 8 * 60 * minute,
                t1: day + 8 * 60 * minute + (i + 1) * minute,
                v: 0.25,
              ),
          ],
        ),
      ]);
      await store.refreshSessionSummaries();

      Future<double?> total(String metric) async => (await store.dailyRange(
        metric: metric,
        fromDay: day,
        toDay: day,
      )).single.total;

      expect(await total(HealthMetrics.distance), 6.0);
      expect(await total(HealthMetrics.hydration), 0.5);

      final runs = await store.sessions(kind: HealthSchema.sessionKindExercise);
      expect(runs, hasLength(1));
      expect(runs.single.distanceKm, 5.0);

      await store.rebuildDaily();
      expect(await total(HealthMetrics.distance), 6.0);
    });
  });
}

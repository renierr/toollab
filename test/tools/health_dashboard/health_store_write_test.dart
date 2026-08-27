import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_rows.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_schema.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_models.dart';
import 'package:tool_lab/tools/health_dashboard/store/health_store.dart';

/// The trailing safety pass re-reads a window on every sync, so what
/// `writeRecords` reports has to be what the store gained - otherwise a sync
/// that changed nothing announces thousands of changes and marks the day dirty.
void main() {
  const day = 1735689600000; // 2025-01-01T00:00:00Z

  HealthMappedRecord recordAt(int offsetMinutes) => HealthMappedRecord(
    package: 'com.example.watch',
    points: [
      for (var i = 0; i < 3; i++)
        HealthPointRow(
          metric: 'heart_rate',
          t: day + (offsetMinutes + i) * 60000,
          v: 60 + i.toDouble(),
        ),
    ],
    intervals: [
      HealthIntervalRow(
        metric: 'steps',
        t0: day + offsetMinutes * 60000,
        t1: day + (offsetMinutes + 5) * 60000,
        v: 400,
      ),
    ],
    session: HealthSessionRow(
      kind: HealthSchema.sessionKindExercise,
      t0: day + offsetMinutes * 60000,
      t1: day + (offsetMinutes + 30) * 60000,
      origin: 'record-$offsetMinutes',
    ),
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('writeRecords counts stored rows, not offered ones', () async {
    final store = HealthStore.instance;

    // Three points, one interval, one session.
    expect(await store.writeRecords([recordAt(0)]), 5);

    // The same page again: every row collapses on its key.
    expect(await store.writeRecords([recordAt(0)]), 0);

    // A later page still reports only what it added.
    expect(await store.writeRecords([recordAt(0), recordAt(60)]), 5);
  });

  test('a re-read that stores nothing leaves the chunk clean', () async {
    final store = HealthStore.instance;
    await store.writeRecords([recordAt(600)]);

    for (final chunk in await store.chunkManifest(onlyDirty: true)) {
      await store.finalizeChunk(
        HealthChunkMeta.parseId(chunk.id)!.$1,
        HealthChunkMeta.parseId(chunk.id)!.$2,
        false,
      );
    }
    expect(await store.chunkManifest(onlyDirty: true), isEmpty);

    await store.writeRecords([recordAt(600)]);
    expect(await store.chunkManifest(onlyDirty: true), isEmpty);
  });
}

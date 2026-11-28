import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/trimz/models/trimz_saved_series.dart';
import 'package:tool_lab/tools/trimz/trimz_db_helper.dart';
import 'package:tool_lab/tools/trimz/trimz_sync_delegate.dart';

TrimzSavedSeries _series(String id, {int? watchedAt = 1, int? savedAt}) =>
    TrimzSavedSeries(
      id: id,
      slug: 'slug-$id',
      title: 'Title $id',
      episodeCount: 10,
      episodeIndex: 3,
      positionMs: 20000,
      durationMs: 60000,
      watchedAt: watchedAt,
      savedAt: savedAt,
    );

void main() {
  final db = TrimzDbHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  Future<Map<String, Map<String, dynamic>>> localMeta(
    TrimzSyncDelegate delegate,
  ) async => {
    for (final r in await delegate.getLocalSyncRecords()) r['id'] as String: r,
  };

  test('pushes a saved series with its progress', () async {
    await db.save(_series('a'));
    final delegate = TrimzSyncDelegate();
    final meta = (await localMeta(delegate))['a']!;
    expect(meta['deleted'], isFalse);
    expect(meta['updatedAt'], greaterThan(0));

    final data = (await delegate.getLocalRecordData('a'))!;
    expect(data['shortId'], 'a');
    final copy = TrimzSavedSeries.fromSyncData('a', data);
    expect(copy.toMap(), _series('a').toMap());
  });

  test('a deletion stays as a tombstone until it was pushed', () async {
    await db.save(_series('b'));
    await db.delete('b');
    expect((await db.all()).map((s) => s.id), isNot(contains('b')));

    final delegate = TrimzSyncDelegate();
    expect((await localMeta(delegate))['b']!['deleted'], isTrue);
    expect(await delegate.getLocalRecordData('b'), isNull);

    await delegate.finalizeLocalSync('b', true);
    expect(await localMeta(TrimzSyncDelegate()), isNot(contains('b')));
  });

  test('saving after a deletion revives the row above its tombstone', () async {
    await db.save(_series('c'));
    await db.delete('c');
    final tombstone = (await localMeta(TrimzSyncDelegate()))['c']!;
    await db.save(_series('c'));
    final revived = (await localMeta(TrimzSyncDelegate()))['c']!;
    expect(revived['deleted'], isFalse);
    expect(
      revived['updatedAt'] as int,
      greaterThan(tombstone['updatedAt'] as int),
    );
  });

  test('a pulled row replaces only an older local row', () async {
    await db.save(_series('d'));
    final local = (await localMeta(TrimzSyncDelegate()))['d']!;
    final localAt = local['updatedAt'] as int;
    final delegate = TrimzSyncDelegate();
    final changes = <void>[];
    final sub = db.remoteChanges.listen(changes.add);
    addTearDown(sub.cancel);

    final remote = _series('d').copyWith(episodeIndex: 7).toSyncData();
    await delegate.savePulledRecord(
      id: 'd',
      data: remote,
      updatedAt: localAt - 1,
      deleted: false,
    );
    expect((await db.live('d'))!.episodeIndex, 3);

    await delegate.savePulledRecord(
      id: 'd',
      data: remote,
      updatedAt: localAt + 1,
      deleted: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect((await db.live('d'))!.episodeIndex, 7);
    expect(changes, hasLength(1));
  });

  test('a server tombstone keeps a row changed after it was read', () async {
    await db.save(_series('e'));
    final delegate = TrimzSyncDelegate();
    await delegate.getLocalSyncRecords();
    await db.save(_series('e').copyWith(episodeIndex: 5));
    await delegate.finalizeLocalSync('e', true);
    expect((await db.live('e'))!.episodeIndex, 5);
  });

  test('clearing the list tombstones list-only rows', () async {
    await db.save(_series('f', watchedAt: null, savedAt: 1));
    await db.save(_series('g', savedAt: 1));
    await db.clearList();
    final meta = await localMeta(TrimzSyncDelegate());
    expect(meta['f']!['deleted'], isTrue);
    expect(meta['g']!['deleted'], isFalse);
    expect((await db.live('g'))!.savedAt, isNull);
  });
}

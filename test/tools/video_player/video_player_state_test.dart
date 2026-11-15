import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/video_player/video_player_state.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  final movie = Uri.file('/videos/movie.mkv');
  final clip = Uri.file('/videos/clip.mp4');

  Future<void> save(
    VideoPlayerState state,
    Uri source,
    int positionSeconds, {
    int durationSeconds = 600,
  }) => state.savePosition(
    source: source,
    title: source.pathSegments.last,
    position: Duration(seconds: positionSeconds),
    duration: Duration(seconds: durationSeconds),
  );

  test('resumes a started video, not a new or finished one', () async {
    final state = VideoPlayerState();
    expect(await state.resumePosition(movie), isNull);

    await save(state, movie, 2);
    expect(await state.resumePosition(movie), isNull);

    await save(state, movie, 120);
    expect(await state.resumePosition(movie), const Duration(seconds: 120));

    await save(state, movie, 595);
    expect(await state.resumePosition(movie), isNull);
  });

  test('lists the latest video first and removes entries', () async {
    final state = VideoPlayerState();
    await state.load();
    await save(state, movie, 60);
    await save(state, clip, 30);
    expect(state.entries.map((e) => e.title), ['clip.mp4', 'movie.mkv']);

    await save(state, movie, 90);
    expect(state.entries.first.title, 'movie.mkv');
    expect(state.entries.first.position, const Duration(seconds: 90));

    await state.remove(state.entries.first);
    expect(state.entries.map((e) => e.title), ['clip.mp4']);

    await state.clear();
    expect(state.entries, isEmpty);
    expect(await state.resumePosition(clip), isNull);
  });

  test('keeps at most the newest entries', () async {
    final state = VideoPlayerState();
    await state.load();
    for (var i = 0; i < VideoPlayerState.maxEntries + 3; i++) {
      await save(state, Uri.file('/videos/$i.mp4'), 60);
    }
    expect(state.entries, hasLength(VideoPlayerState.maxEntries));
    expect(state.entries.first.title, '${VideoPlayerState.maxEntries + 2}.mp4');
    expect(await state.resumePosition(Uri.file('/videos/0.mp4')), isNull);

    final reloaded = VideoPlayerState();
    await reloaded.load();
    expect(reloaded.entries, hasLength(VideoPlayerState.maxEntries));
    await state.clear();
  });
}

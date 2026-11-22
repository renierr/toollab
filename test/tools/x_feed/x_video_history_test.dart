import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/x_feed/models/x_watched_video.dart';
import 'package:tool_lab/tools/x_feed/x_video_history.dart';
import 'package:tool_lab/tools/x_feed/x_video_history_db.dart';
import 'package:tool_lab/widgets/video_player/video_backend.dart';

XWatchedVideo _video(String id, {DateTime? at}) {
  final time = at ?? DateTime(2026, 11, 22, 12);
  return XWatchedVideo(
    postId: id,
    mediaIndex: 0,
    authorScreenName: 'someone',
    authorName: 'Some One',
    avatarUrl: null,
    text: 'text',
    videoUrl: 'https://video.twimg.com/$id.mp4',
    previewUrl: 'https://pbs.twimg.com/$id.jpg',
    isGif: false,
    duration: const Duration(seconds: 30),
    watched: const Duration(seconds: 10),
    playCount: 1,
    firstWatchedAt: time,
    lastWatchedAt: time,
  );
}

VideoPlaybackState _at(int ms, {int duration = 60000, bool playing = true}) =>
    VideoPlaybackState(
      initialized: true,
      playing: playing,
      position: Duration(milliseconds: ms),
      duration: Duration(milliseconds: duration),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  setUp(() => XVideoHistoryDb.instance.clearOlderThan(null));

  test('threshold is the setting or half of a short video', () {
    final history = XVideoHistory();
    expect(
      history.thresholdFor(const Duration(seconds: 60)),
      const Duration(seconds: 5),
    );
    expect(
      history.thresholdFor(const Duration(seconds: 6)),
      const Duration(seconds: 3),
    );
  });

  test('groups by period of the last view', () {
    final now = DateTime(2026, 11, 22, 18);
    final groups = XVideoHistory.group([
      _video('a', at: DateTime(2026, 11, 22, 9)),
      _video('b', at: DateTime(2026, 11, 19)),
      _video('c', at: DateTime(2026, 11, 1)),
      _video('d', at: DateTime(2026, 3, 1)),
      _video('e', at: DateTime(2024, 3, 1)),
    ], now: now);
    expect(groups.map((g) => g.period), XHistoryPeriod.values);
    expect(groups.first.entries.single.postId, 'a');
  });

  test('records once past the threshold, seeks do not count', () async {
    final history = XVideoHistory();
    final video = _video('p');
    final source = Uri.parse(video.videoUrl);
    final watch = history.watch({source: video});

    watch.onProgress(source, _at(0));
    watch.onProgress(source, _at(30000));
    watch.onProgress(source, _at(31000));
    expect(await XVideoHistoryDb.instance.entries(), isEmpty);

    for (var ms = 31500; ms <= 36000; ms += 500) {
      watch.onProgress(source, _at(ms));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var entries = await XVideoHistoryDb.instance.entries();
    expect(entries.single.playCount, 1);
    expect(entries.single.watched, const Duration(seconds: 5));

    watch.onProgress(source, _at(38000));
    watch.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    entries = await XVideoHistoryDb.instance.entries();
    expect(entries.single.watched, const Duration(seconds: 8));
    expect(entries.single.playCount, 1);
  });

  test('clears entries older than an age', () async {
    final db = XVideoHistoryDb.instance;
    await db.restore(
      _video('old', at: DateTime.now().subtract(const Duration(days: 40))),
    );
    await db.restore(_video('new', at: DateTime.now()));
    expect(await db.clearOlderThan(const Duration(days: 30)), 1);
    expect((await db.entries()).single.postId, 'new');
  });
}

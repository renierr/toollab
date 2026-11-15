import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/widgets/video_player/video_backend.dart';
import 'package:tool_lab/widgets/video_player/video_keymap.dart';
import 'package:tool_lab/widgets/video_player/video_player_types.dart';
import 'package:tool_lab/widgets/video_player/video_progress_saver.dart';
import 'package:tool_lab/widgets/video_player/video_resume_store.dart';
import 'package:tool_lab/widgets/video_player/video_seek_bar.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/video_player/video_stall_watchdog.dart';
import 'package:tool_lab/widgets/video_player/video_sync_dialog.dart';
import 'package:tool_lab/widgets/video_player/video_thumbnailer.dart';

class _Store implements VideoResumeStore {
  final List<Duration> saved = [];

  @override
  Future<Duration?> resumePosition(Uri source) async => null;

  @override
  Future<void> savePosition({
    required Uri source,
    required String title,
    required Duration position,
    required Duration duration,
  }) async => saved.add(position);

  @override
  Future<void> saveThumbnail(Uri source, Uint8List jpeg) async =>
      thumbnails.add(jpeg);

  final List<Uint8List> thumbnails = [];
}

KeyEvent _down(LogicalKeyboardKey key, {String? character}) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  character: character,
  timeStamp: Duration.zero,
);

KeyEvent _repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  group('videoKeyCommand', () {
    test('maps keys and ignores releases', () {
      expect(
        videoKeyCommand(_down(LogicalKeyboardKey.space)),
        VideoKeyCommand.togglePlay,
      );
      expect(
        videoKeyCommand(_down(LogicalKeyboardKey.keyL)),
        VideoKeyCommand.skipForward,
      );
      expect(
        videoKeyCommand(
          const KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            timeStamp: Duration.zero,
          ),
        ),
        isNull,
      );
    });

    test('press-only keys do not repeat', () {
      expect(
        videoKeyCommand(_down(LogicalKeyboardKey.keyM)),
        VideoKeyCommand.toggleMute,
      );
      expect(
        videoKeyCommand(_repeat(LogicalKeyboardKey.keyM)),
        VideoKeyCommand.other,
      );
      expect(
        videoKeyCommand(_repeat(LogicalKeyboardKey.arrowLeft)),
        VideoKeyCommand.arrowBack,
      );
    });

    test('speed keys follow the typed character', () {
      expect(
        videoKeyCommand(_down(LogicalKeyboardKey.less, character: '<')),
        VideoKeyCommand.slower,
      );
      expect(
        videoKeyCommand(_down(LogicalKeyboardKey.greater, character: '>')),
        VideoKeyCommand.faster,
      );
    });
  });

  test('lowerVideoQuality skips adaptive renditions', () {
    final auto = VideoQuality(
      label: 'Auto',
      source: Uri.parse('a'),
      adaptive: true,
    );
    final high = VideoQuality(label: '720p', source: Uri.parse('h'));
    final low = VideoQuality(label: '360p', source: Uri.parse('l'));
    final list = [high, auto, low];
    expect(lowerVideoQuality(list, high.source), low);
    expect(lowerVideoQuality(list, low.source), isNull);
    expect(lowerVideoQuality(list, Uri.parse('x')), isNull);
  });

  test('progress saver throttles while playing', () {
    final store = _Store();
    final saver = VideoProgressSaver(store);
    VideoPlaybackState at(int s, {bool playing = true}) => VideoPlaybackState(
      initialized: true,
      playing: playing,
      position: Duration(seconds: s),
      duration: const Duration(minutes: 10),
    );
    final source = Uri.file('/v.mp4');
    saver.save(source: source, title: 'v', state: at(1));
    saver.save(source: source, title: 'v', state: at(2));
    expect(store.saved, [const Duration(seconds: 1)]);
    saver.save(source: source, title: 'v', state: at(3, playing: false));
    saver.save(
      source: source,
      title: 'v',
      state: at(3, playing: false),
      force: true,
    );
    expect(store.saved, hasLength(3));
  });

  testWidgets('stall watchdog fires after the limit and clears once playing', (
    tester,
  ) async {
    var stalls = 0;
    final watchdog = VideoStallWatchdog(onStall: () => stalls++)
      ..resumeAt = const Duration(seconds: 30);
    watchdog.watch(const VideoPlaybackState());
    await tester.pump(VideoStallWatchdog.limit);
    expect(stalls, 1);

    watchdog.watch(const VideoPlaybackState());
    watchdog.watch(
      const VideoPlaybackState(
        initialized: true,
        playing: true,
        duration: Duration(minutes: 5),
      ),
    );
    await tester.pump(VideoStallWatchdog.limit);
    expect(stalls, 1);
    expect(watchdog.resumeAt, isNull);
  });

  testWidgets('seek bar seeks once on release', (tester) async {
    final seeks = <Duration>[];
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSeekBar(
            position: Duration.zero,
            duration: const Duration(minutes: 10),
            onSeekStart: () => starts++,
            onSeek: seeks.add,
          ),
        ),
      ),
    );
    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    expect(seeks, isEmpty);
    expect(starts, 1);
    await gesture.up();
    await tester.pump();
    expect(seeks, hasLength(1));
    expect(seeks.single, greaterThan(const Duration(minutes: 5)));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('thumbnailer takes a frame on pause and when due', (
    tester,
  ) async {
    final store = _Store();
    final thumbnailer = VideoThumbnailer(store);
    var captures = 0;
    Future<Uint8List?> capture() async {
      captures++;
      return Uint8List(1);
    }

    VideoPlaybackState at(int s, {bool playing = true}) => VideoPlaybackState(
      initialized: true,
      playing: playing,
      position: Duration(seconds: s),
      duration: const Duration(minutes: 10),
    );
    final source = Uri.file('/v.mp4');
    thumbnailer.watch(source: source, state: at(1), capture: capture);
    expect(captures, 0);
    thumbnailer.watch(source: source, state: at(5), capture: capture);
    await tester.pump();
    expect(captures, 1);
    thumbnailer.watch(source: source, state: at(6), capture: capture);
    await tester.pump();
    expect(captures, 1);
    thumbnailer.watch(
      source: source,
      state: at(7, playing: false),
      capture: capture,
    );
    await tester.pump();
    expect(captures, 2);
    expect(store.thumbnails, hasLength(2));
  });

  testWidgets('seek bar shows the buffered range', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSeekBar(
            position: const Duration(minutes: 1),
            duration: const Duration(minutes: 10),
            buffered: const Duration(minutes: 3),
            onSeekStart: () {},
            onSeek: (_) {},
          ),
        ),
      ),
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(
      slider.secondaryTrackValue,
      const Duration(minutes: 3).inMilliseconds,
    );
  });

  testWidgets('sync dialog steps and resets the delays', (tester) async {
    Duration? subtitle;
    Duration? audio;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoSyncDialog(
            subtitleDelay: Duration.zero,
            audioDelay: Duration.zero,
            onSubtitleDelay: (d) => subtitle = d,
            onAudioDelay: (d) => audio = d,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.remove).last);
    await tester.pump();
    expect(subtitle, VideoSyncDialog.step);
    expect(audio, -VideoSyncDialog.step);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(subtitle, Duration.zero);
    expect(audio, Duration.zero);
  });
}

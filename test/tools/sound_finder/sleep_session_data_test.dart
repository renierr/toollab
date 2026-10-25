import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_chunk_analyzer.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_data.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_store.dart';

SleepChunkAnalysis analysis(
  SleepSoundCategory category,
  List<SleepSubEvent> subs,
) => SleepChunkAnalysis(
  category: category,
  confidence: 0.8,
  levelDb: -20,
  floorDb: -60,
  activeMs: subs.fold(0, (a, s) => a + s.durationMs),
  firstActiveMs: subs.isEmpty ? 0 : subs.first.startMs,
  lastActiveMs: subs.isEmpty ? 0 : subs.last.endMs,
  loudestMs: subs.isEmpty ? 0 : subs.first.startMs,
  bursts: subs.length,
  centroidHz: 300,
  dominantHz: 120,
  lowRatio: 0.6,
  flatness: 0.1,
  periodicity: 0,
  periodSec: 0,
  subEvents: subs,
);

void main() {
  SleepSessionData session() => SleepSessionData(
    path: '/root/session-20261018-230000',
    startedAt: DateTime(2026, 10, 18, 23),
    endedAt: DateTime(2026, 10, 19, 7),
    targetMinutes: 480,
    threshold: 0.005,
    adaptiveThreshold: false,
    events: [
      SleepEvent(
        fileName: 'chunk-20261019-010015.wav',
        startedAt: DateTime(2026, 10, 19, 1),
        endedAt: DateTime(2026, 10, 19, 1, 0, 15),
        peakAmplitude: 0.1,
        annotation: 'cough',
      ),
    ],
    updatedAt: 42,
  );

  SleepSessionData sessionWith(
    List<SleepEvent> events, {
    List<SleepLevelSample> levels = const [],
  }) => SleepSessionData(
    path: '/root/session-20261018-230000',
    startedAt: DateTime(2026, 10, 18, 23),
    endedAt: DateTime(2026, 10, 19, 7),
    targetMinutes: 480,
    threshold: 0.005,
    adaptiveThreshold: false,
    events: events,
    levels: levels,
  );

  test('json round trip keeps events, times and sync clock', () {
    final original = session();
    final copy = SleepSessionData.fromJson(original.path, original.toJson());
    expect(copy.startedAt, original.startedAt);
    expect(copy.endedAt, original.endedAt);
    expect(copy.updatedAt, 42);
    expect(copy.events.single.fileName, 'chunk-20261019-010015.wav');
    expect(copy.events.single.endedAt, original.events.single.endedAt);
    expect(copy.events.single.annotation, 'cough');
  });

  test('times are stored as UTC', () {
    final json = session().toJson();
    expect(json['startedAt'], endsWith('Z'));
  });

  test('level samples round trip and give a quiet-room floor', () {
    final start = DateTime(2026, 10, 18, 23);
    final original = sessionWith(
      [
        SleepEvent(
          fileName: 'chunk-20261019-010015.wav',
          startedAt: DateTime(2026, 10, 19, 1),
          endedAt: DateTime(2026, 10, 19, 1, 0, 15),
          peakAmplitude: 0.1,
        ),
      ],
      levels: [
        for (var i = 0; i < 10; i++)
          SleepLevelSample(
            at: start.add(Duration(seconds: i * 15)),
            peakDb: -18,
            rmsDb: -70.0 + i * 4,
          ),
      ],
    );
    final copy = SleepSessionData.fromJson(original.path, original.toJson());
    expect(copy.levels, hasLength(10));
    expect(copy.levels[3].at, original.levels[3].at);
    expect(copy.levels[3].rmsDb, closeTo(-58, 0.05));
    expect(copy.noiseFloorDb, closeTo(-62, 0.05));
    expect(session().noiseFloorDb, isNull);
  });

  test('sound spans merge one sound across chunk boundaries', () {
    final data = sessionWith([
      SleepEvent(
        fileName: 'a.wav',
        startedAt: DateTime(2026, 10, 19, 1),
        endedAt: DateTime(2026, 10, 19, 1, 0, 15),
        peakAmplitude: 0.2,
        analysis: analysis(SleepSoundCategory.snore, const [
          SleepSubEvent(
            startMs: 12000,
            endMs: 15000,
            category: SleepSoundCategory.snore,
            confidence: 0.8,
            peakDb: -20,
          ),
        ]),
      ),
      SleepEvent(
        fileName: 'b.wav',
        startedAt: DateTime(2026, 10, 19, 1, 0, 15),
        endedAt: DateTime(2026, 10, 19, 1, 0, 30),
        peakAmplitude: 0.2,
        analysis: analysis(SleepSoundCategory.snore, const [
          SleepSubEvent(
            startMs: 0,
            endMs: 2000,
            category: SleepSoundCategory.snore,
            confidence: 0.6,
            peakDb: -22,
          ),
        ]),
      ),
    ]);
    final spans = data.soundSpans;
    expect(spans, hasLength(1));
    expect(spans.single.start, DateTime(2026, 10, 19, 1, 0, 12));
    expect(spans.single.end, DateTime(2026, 10, 19, 1, 0, 17));
    expect(spans.single.confidence, closeTo(0.7, 0.001));
    expect(
      data.soundDurations[SleepSoundCategory.snore],
      const Duration(seconds: 5),
    );
  });

  test('legacy absolute file paths are reduced to the file name', () {
    final event = SleepEvent.fromJson({
      'file': r'C:\docs\sleep_recordings\session-x\chunk-1.wav',
      'startedAt': '2026-10-19T01:00:00.000',
      'endedAt': '2026-10-19T01:00:15.000',
      'peakAmplitude': 0.1,
    });
    expect(event.fileName, 'chunk-1.wav');
    expect(event.startedAt, DateTime(2026, 10, 19, 1));
  });

  test('sync ids split into session and chunk', () {
    final id = SleepSessionStore.chunkSyncId('session-1', 'chunk-2.wav');
    expect(SleepSessionStore.parseSyncId(id), ('session-1', 'chunk-2.wav'));
    expect(SleepSessionStore.parseSyncId('session-1'), ('session-1', null));
  });
}

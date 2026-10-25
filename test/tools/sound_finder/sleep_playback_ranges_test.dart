import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_chunk_analyzer.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_playback_ranges.dart';

void main() {
  SleepChunkAnalysis analysis(List<SleepSubEvent> subs) => SleepChunkAnalysis(
    category: SleepSoundCategory.snore,
    confidence: 0.8,
    levelDb: -30,
    floorDb: -60,
    activeMs: 2000,
    firstActiveMs: 1000,
    lastActiveMs: 11000,
    loudestMs: 1000,
    bursts: subs.length,
    centroidHz: 100,
    dominantHz: 100,
    lowRatio: 0.7,
    flatness: 0.1,
    periodicity: 0,
    periodSec: 0,
    subEvents: subs,
  );

  test('skips leading, internal, and trailing quiet but pads each sound', () {
    final ranges = sleepPlaybackRanges(
      analysis(const [
        SleepSubEvent(
          startMs: 1000,
          endMs: 2000,
          category: SleepSoundCategory.snore,
          confidence: 0.8,
        ),
        SleepSubEvent(
          startMs: 10000,
          endMs: 11000,
          category: SleepSoundCategory.cough,
          confidence: 0.7,
        ),
      ]),
      const Duration(seconds: 15),
    );
    expect(ranges, [
      (const Duration(milliseconds: 700), const Duration(milliseconds: 2300)),
      (const Duration(milliseconds: 9700), const Duration(milliseconds: 11300)),
    ]);
    expect(nextSleepPlaybackPosition(ranges, Duration.zero), ranges.first.$1);
    expect(
      nextSleepPlaybackPosition(ranges, const Duration(seconds: 1)),
      const Duration(seconds: 1),
    );
    expect(nextSleepPlaybackPosition(ranges, ranges.first.$2), ranges.last.$1);
    expect(nextSleepPlaybackPosition(ranges, ranges.last.$2), isNull);
  });

  test('overlapping padding merges and clamps to chunk boundaries', () {
    final ranges = sleepPlaybackRanges(
      analysis(const [
        SleepSubEvent(
          startMs: 100,
          endMs: 800,
          category: SleepSoundCategory.snore,
          confidence: 0.8,
        ),
        SleepSubEvent(
          startMs: 1000,
          endMs: 2500,
          category: SleepSoundCategory.cough,
          confidence: 0.7,
        ),
      ]),
      const Duration(milliseconds: 2600),
    );
    expect(ranges, [(Duration.zero, const Duration(milliseconds: 2600))]);
    expect(sleepPlaybackRanges(null, const Duration(seconds: 15)), isEmpty);
  });

  test('legacy analyses without sub-events retain edge trimming', () {
    final legacy = SleepChunkAnalysis(
      category: SleepSoundCategory.snore,
      confidence: 0.8,
      levelDb: -30,
      floorDb: -60,
      activeMs: 1000,
      firstActiveMs: 1000,
      lastActiveMs: 2000,
      loudestMs: 1500,
      bursts: 1,
      centroidHz: 100,
      dominantHz: 100,
      lowRatio: 0.7,
      flatness: 0.1,
      periodicity: 0,
      periodSec: 0,
    );
    expect(sleepPlaybackRanges(legacy, const Duration(seconds: 15)), [
      (const Duration(milliseconds: 700), const Duration(milliseconds: 2300)),
    ]);
  });

  test('gain is capped by measured peak, not the requested boost', () {
    expect(safeSleepPlaybackGain(4, 0.1), 4);
    expect(safeSleepPlaybackGain(4, 0.5), closeTo(1.9, 0.001));
    expect(safeSleepPlaybackGain(1, 0.98), 1);
  });
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_chunk_analyzer.dart';

const _sr = 44100;

/// 15 s chunk of [signal] over a faint, fixed-seed noise floor.
Float32List _chunk(double Function(double t, math.Random rnd) signal) {
  final rnd = math.Random(1);
  return Float32List.fromList(
    List.generate(
      _sr * 15,
      (i) => signal(i / _sr, rnd) + (rnd.nextDouble() - 0.5) * 0.002,
    ),
  );
}

void main() {
  test('rhythmic low hum is snoring', () {
    final a = SleepChunkAnalyzer.analyze(
      _chunk(
        (t, _) => t % 4 < 1.2
            ? 0.3 *
                  math.sin(2 * math.pi * 120 * t) *
                  (1 + 0.5 * math.sin(2 * math.pi * 30 * t))
            : 0,
      ),
      _sr,
    );
    expect(a.category, SleepSoundCategory.snore);
    expect(a.bursts, greaterThanOrEqualTo(3));
    expect(a.periodSec, closeTo(4, 0.3));
  });

  test('short sharp burst is an impulse', () {
    final a = SleepChunkAnalyzer.analyze(
      _chunk(
        (t, _) => t > 5 && t < 5.08 ? 0.6 * math.sin(2 * math.pi * 900 * t) : 0,
      ),
      _sr,
    );
    expect(a.category, SleepSoundCategory.impulse);
    expect(a.bursts, 1);
    expect(a.firstActiveMs, closeTo(5000, 100));
  });

  test('broadband noise burst is movement', () {
    final a = SleepChunkAnalyzer.analyze(
      _chunk((t, rnd) => t > 3 && t < 9 ? (rnd.nextDouble() - 0.5) * 0.3 : 0),
      _sr,
    );
    expect(a.category, SleepSoundCategory.movement);
    expect(a.flatness, greaterThan(0.5));
  });

  test('constant noise without events is steady', () {
    final a = SleepChunkAnalyzer.analyze(
      _chunk((_, rnd) => (rnd.nextDouble() - 0.5) * 0.05),
      _sr,
    );
    expect(a.category, SleepSoundCategory.steady);
    expect(a.bursts, 0);
  });

  test('analysis survives a json round trip', () {
    final a = SleepChunkAnalyzer.analyze(
      _chunk(
        (t, _) => t > 2 && t < 3 ? 0.2 * math.sin(2 * math.pi * 200 * t) : 0,
      ),
      _sr,
    );
    final b = SleepChunkAnalysis.fromJson(a.toJson());
    expect(b.category, a.category);
    expect(b.firstActiveMs, a.firstActiveMs);
    expect(b.lastActiveMs, a.lastActiveMs);
    expect(b.bursts, a.bursts);
  });
}

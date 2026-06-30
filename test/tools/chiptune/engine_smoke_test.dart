import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chiptune/engine/mixer.dart';
import 'package:tool_lab/tools/chiptune/engine/module.dart';

/// Builds a minimal 1-channel MOD that triggers a looping square-wave sample,
/// so the mixer exercises trigger -> sample playback -> render end to end.
ModuleFile _buildSquareWaveModule() {
  final data = Float32List(64);
  for (int i = 0; i < 64; i++) {
    data[i] = i < 32 ? 0.8 : -0.8;
  }

  final sample = Sample(
    name: 'square',
    length: 64,
    volume: 64,
    loopStart: 0,
    loopLength: 64,
    data: data,
  );

  final instrument = Instrument(
    name: 'square',
    samples: [sample],
    sampleMap: List<int>.filled(120, 0),
    volumeFadeout: 0,
  );

  // Row 0 triggers C with an explicit Amiga period; remaining rows are empty.
  final rows = <List<Note>>[];
  for (int r = 0; r < 8; r++) {
    rows.add([r == 0 ? Note(note: 25, period: 428, instrument: 1) : Note()]);
  }

  return ModuleFile(
    type: 'MOD',
    title: 'smoke',
    instruments: [instrument],
    patterns: [Pattern(rows: rows)],
    sequence: [0],
    channels: 1,
    defaultBpm: 125,
    defaultSpeed: 6,
    rowsPerPattern: 8,
  );
}

void main() {
  test('mixer renders non-silent PCM for a triggered sample', () {
    final mod = _buildSquareWaveModule();
    final mixer = ChiptuneMixer();
    mixer.loadAndPlay(serializeModuleForWorklet(mod), 44100, looping: true);

    const frames = 4096;
    final out = Float32List(frames * 2);

    double peak = 0;
    bool allFinite = true;
    for (int chunk = 0; chunk < 8; chunk++) {
      mixer.render(out, frames);
      for (final s in out) {
        if (!s.isFinite) allFinite = false;
        final a = s.abs();
        if (a > peak) peak = a;
      }
    }

    expect(allFinite, isTrue, reason: 'mixer produced NaN/Inf samples');
    expect(peak, greaterThan(0.0), reason: 'mixer produced silence');
    expect(peak, lessThanOrEqualTo(1.0), reason: 'output not within [-1,1]');
  });

  test('mixer fills silence and stays finite when not playing', () {
    final mixer = ChiptuneMixer();
    final out = Float32List(512)..fillRange(0, 512, 1);
    mixer.render(out, 256);
    expect(out.every((s) => s == 0.0), isTrue);
  });

  test('pattern loop (E6x) terminates instead of playing forever', () {
    // Row 0: loop start (E60); row 1: loop twice (E62); rows 2-3 follow.
    final rows = <List<Note>>[
      [Note(effect: 0x0e, effectParam: 0x60)],
      [Note(effect: 0x0e, effectParam: 0x62)],
      [Note()],
      [Note()],
    ];
    final mod = ModuleFile(
      type: 'MOD',
      patterns: [Pattern(rows: rows)],
      sequence: [0],
      channels: 1,
      defaultBpm: 125,
      defaultSpeed: 1, // 1 tick/row -> advances quickly
      rowsPerPattern: 4,
    );

    final mixer = ChiptuneMixer();
    bool ended = false;
    mixer.onEnded = () => ended = true;
    // Non-looping: the song must end on its own once the pattern loop expires.
    mixer.loadAndPlay(serializeModuleForWorklet(mod), 44100, looping: false);

    const frames = 4096;
    final out = Float32List(frames * 2);
    // ~10s of audio is far more than this <1s song needs; a broken loop would
    // never set `ended` no matter how long we render.
    for (int i = 0; i < 120 && !ended; i++) {
      mixer.render(out, frames);
    }

    expect(ended, isTrue, reason: 'pattern loop never terminated');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chiptune/engine/module.dart';
import 'package:tool_lab/tools/chiptune/engine/song_duration.dart';

/// One row at speed 6 / 125 BPM lasts 6 * 2.5 / 125 = 0.12s.
const double _baseRowSeconds = 6 * 2.5 / 125;

Pattern _emptyPattern(int rows, int channels) {
  return Pattern(
    rows: List.generate(
      rows,
      (_) => List.generate(channels, (_) => Note()),
    ),
  );
}

ModuleFile _mod({
  required List<Pattern> patterns,
  required List<int> sequence,
  String type = 'MOD',
  int speed = 6,
  int bpm = 125,
}) {
  return ModuleFile(
    type: type,
    patterns: patterns,
    sequence: sequence,
    channels: 1,
    defaultSpeed: speed,
    defaultBpm: bpm,
    rowsPerPattern: patterns.isEmpty ? 64 : patterns.first.rows.length,
  );
}

void main() {
  test('sums plain row times at default speed/tempo', () {
    final mod = _mod(
      patterns: [_emptyPattern(64, 1), _emptyPattern(64, 1)],
      sequence: [0, 1],
    );
    final d = estimateSongDuration(mod);
    expect(d.inMilliseconds, (128 * _baseRowSeconds * 1000).round());
  });

  test('honours a mid-song tempo change (Fxx >= 32 sets BPM)', () {
    final pat = _emptyPattern(4, 1);
    // Row 0 sets BPM to 250 (Fxx, param 250) -> rows run at 6 * 2.5 / 250.
    pat.rows[0][0] = Note(effect: 0x0f, effectParam: 250);
    final mod = _mod(patterns: [pat], sequence: [0]);
    final d = estimateSongDuration(mod);
    expect(d.inMilliseconds, (4 * (6 * 2.5 / 250) * 1000).round());
  });

  test('pattern break (Dxx) shortens the song', () {
    final pat = _emptyPattern(64, 1);
    // Break after row 1 -> only rows 0 and 1 of each order play.
    pat.rows[1][0] = Note(effect: 0x0d, effectParam: 0);
    final mod = _mod(patterns: [pat], sequence: [0, 0]);
    final d = estimateSongDuration(mod);
    expect(d.inMilliseconds, (4 * _baseRowSeconds * 1000).round());
  });

  test('pattern loop (E6x) repeats rows a finite number of times', () {
    final pat = _emptyPattern(4, 1);
    pat.rows[0][0] = Note(effect: 0x0e, effectParam: 0x60); // loop start
    pat.rows[1][0] = Note(effect: 0x0e, effectParam: 0x62); // loop 2x
    final mod = _mod(patterns: [pat], sequence: [0]);
    // Rows 0,1 play, then loop back to 0 twice (rows 0,1 each extra time),
    // then rows 2,3. Total = 4 base rows + 2 repeats * 2 rows = 8 rows.
    final d = estimateSongDuration(mod);
    expect(d.inMilliseconds, (8 * _baseRowSeconds * 1000).round());
  });

  test('backward position jump (Bxx) terminates instead of looping forever', () {
    final pat = _emptyPattern(2, 1);
    pat.rows[1][0] = Note(effect: 0x0b, effectParam: 0); // jump back to order 0
    final mod = _mod(patterns: [pat], sequence: [0]);
    final d = estimateSongDuration(mod);
    // Plays both rows once, then the backward jump ends the song.
    expect(d.inMilliseconds, (2 * _baseRowSeconds * 1000).round());
    expect(d.inSeconds, lessThan(5));
  });

  test('empty module yields zero', () {
    expect(estimateSongDuration(_mod(patterns: [], sequence: [])), Duration.zero);
  });
}

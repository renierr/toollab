import 'module.dart';

// Effect codes (mirrors the constants the mixer uses in mixer.dart).
const int _fxPositionJump = 0x0b; // Bxx
const int _fxPatternBreak = 0x0d; // Dxx
const int _fxExtended = 0x0e; // Exy
const int _fxSetSpeed = 0x0f; // Fxx (MOD/XM: <32 speed, >=32 tempo)
const int _fxItSetSpeed = 0x20; // IT Axx
const int _fxItSetTempo = 0x21; // IT Txx

/// Computes a song's total play duration by simulating its control flow once,
/// without rendering audio.
///
/// A row plays for `speed * 2.5 / bpm` seconds (the same formula the mixer
/// uses). A naive `rows * rowTime` is wrong because modules change tempo/speed
/// mid-song and jump around via pattern breaks (Dxx), position jumps (Bxx) and
/// pattern loops (E6x). This walks the order list row by row, honouring those
/// effects with non-looping end semantics (a backward jump or running past the
/// last order ends the song) and standard pattern-loop counting.
///
/// IT per-tick tempo slides (Txx slide) are not modelled — they are rare and
/// would require a tick-level pass; the result is otherwise accurate.
Duration estimateSongDuration(ModuleFile mod) => _simulate(mod).time;

class _SimulateResult {
  final Duration time;
  final int order;
  final int row;
  const _SimulateResult(this.time, this.order, this.row);
}

Duration songTimeAt(ModuleFile mod, int targetOrder, int targetRow) =>
    _simulate(mod, targetOrder: targetOrder, targetRow: targetRow).time;

/// Inverse of [songTimeAt]: the order/row the play head sits at after playing
/// for [time]. Used to translate a seek from the media notification into a
/// tracker seek. Falls back to the last simulated position when [time] exceeds
/// the song length.
({int order, int row}) orderRowAtSongTime(ModuleFile mod, Duration time) {
  final result = _simulate(mod, targetTime: time);
  if (result.row < 0) return (order: result.order, row: 0);
  return (order: result.order, row: result.row);
}

_SimulateResult _simulate(
  ModuleFile mod, {
  int? targetOrder,
  int? targetRow,
  Duration? targetTime,
}) {
  if (mod.sequence.isEmpty || mod.patterns.isEmpty) {
    return const _SimulateResult(Duration.zero, 0, -1);
  }

  final bool isMod = mod.type == 'MOD';
  int ticksPerRow = mod.defaultSpeed != 0 ? mod.defaultSpeed : 6;
  int bpm = mod.defaultBpm != 0 ? mod.defaultBpm : 125;

  int position = mod.restartPosition ?? 0;
  if (position < 0 || position >= mod.sequence.length) position = 0;
  int rowIndex = -1;

  int jumpPosition = -1;
  int jumpRowIndex = -1;
  int patternLoopRow = -1;
  int patternLoopPosition = -1;
  int patternLoopCount = 0;
  bool loopJumpPending = false;

  double seconds = 0;
  const int maxRows = 200000; // safety net against pathological loops
  int guard = 0;

  Pattern? patternAt(int pos) {
    if (pos < 0 || pos >= mod.sequence.length) return null;
    final idx = mod.sequence[pos];
    return (idx >= 0 && idx < mod.patterns.length) ? mod.patterns[idx] : null;
  }

  while (guard++ < maxRows) {
    // ---- advance to the next row (mirrors mixer.nextRow, non-looping) ----
    final int previousPosition = position;
    if (loopJumpPending) {
      rowIndex = patternLoopRow;
      position = patternLoopPosition;
      loopJumpPending = false;
    } else if (jumpPosition != -1) {
      // A jump back to the current or an earlier order ends a non-looping song.
      if (jumpPosition <= previousPosition) break;
      position = jumpPosition;
      rowIndex = jumpRowIndex != -1 ? jumpRowIndex : 0;
      jumpPosition = -1;
      jumpRowIndex = -1;
    } else {
      rowIndex++;
      final curPat = patternAt(position);
      if (curPat == null || rowIndex >= curPat.rows.length) {
        rowIndex = 0;
        position++;
      }
    }
    if (position < 0 || position >= mod.sequence.length) break;

    // Stop once the play head reaches the requested seek position: the time
    // accumulated so far is the elapsed time at the start of that row.
    if (targetOrder != null &&
        (position > targetOrder ||
            (position == targetOrder && rowIndex >= targetRow!))) {
      break;
    }

    // Stop once enough play time has accumulated: the current position is the
    // row a seek to [targetTime] should land on. rowIndex < 0 means the caller
    // passed a non-positive target time; clamp to row 0 there.
    if (targetTime != null &&
        seconds * 1000 >= targetTime.inMilliseconds - 0.5) {
      return _SimulateResult(
        Duration(milliseconds: seconds.round()),
        position,
        rowIndex,
      );
    }

    final pat = patternAt(position);
    if (pat == null || rowIndex < 0 || rowIndex >= pat.rows.length) {
      rowIndex = pat == null ? rowIndex : pat.rows.length; // force advance next
      continue;
    }
    final row = pat.rows[rowIndex];

    // ---- apply the row's timing / flow effects (channel order) ----
    int patternDelay = 0;
    for (final note in row) {
      final int p = note.effectParam;
      switch (note.effect) {
        case _fxPositionJump:
          jumpPosition = p;
          jumpRowIndex = 0;
          break;
        case _fxPatternBreak:
          jumpRowIndex = isMod ? ((p >> 4) & 0x0f) * 10 + (p & 0x0f) : p;
          if (jumpPosition == -1) jumpPosition = position + 1;
          break;
        case _fxSetSpeed:
          if (p >= 1 && p < 32) {
            ticksPerRow = p;
          } else if (p >= 32) {
            bpm = p;
          }
          break;
        case _fxItSetSpeed:
          if (p >= 1) ticksPerRow = p;
          break;
        case _fxItSetTempo:
          if (p >= 32) bpm = p;
          break;
        case _fxExtended:
          final int sub = (p >> 4) & 0x0f;
          final int subParam = p & 0x0f;
          if (sub == 0x5 || (sub == 0x6 && subParam == 0)) {
            patternLoopRow = rowIndex;
            patternLoopPosition = position;
          } else if (sub == 0x6 && patternLoopRow >= 0) {
            // Standard E6x loop counting: terminates after `subParam` repeats.
            if (patternLoopCount > 0) {
              patternLoopCount--;
              if (patternLoopCount > 0) loopJumpPending = true;
            } else {
              patternLoopCount = subParam;
              loopJumpPending = true;
            }
          } else if (sub == 0xe) {
            patternDelay = subParam;
          }
          break;
      }
    }

    if (ticksPerRow <= 0) ticksPerRow = 6;
    if (bpm <= 0) bpm = 125;
    // EEx pattern delay repeats the row `patternDelay` extra times.
    seconds += (ticksPerRow * 2.5 / bpm) * (1 + patternDelay);
  }

  return _SimulateResult(
    Duration(milliseconds: (seconds * 1000).round()),
    position < 0
        ? 0
        : (position >= mod.sequence.length
              ? mod.sequence.length - 1
              : position),
    rowIndex,
  );
}

import 'sleep_chunk_analyzer.dart';

/// Padded audible ranges; adjacent sounds keep their shared padding.
List<(Duration, Duration)> sleepPlaybackRanges(
  SleepChunkAnalysis? analysis,
  Duration length, {
  int paddingMs = 300,
}) {
  if (analysis == null || analysis.bursts == 0) return const [];
  final maxMs = length.inMilliseconds;
  if (maxMs <= 0) return const [];
  final List<(int, int)> sounds = analysis.subEvents.isEmpty
      ? [(analysis.firstActiveMs, analysis.lastActiveMs)]
      : [for (final s in analysis.subEvents) (s.startMs, s.endMs)];
  final ranges = <(Duration, Duration)>[];
  for (final (start, end) in sounds) {
    if (end <= start) continue;
    final from = Duration(milliseconds: (start - paddingMs).clamp(0, maxMs));
    final to = Duration(milliseconds: (end + paddingMs).clamp(0, maxMs));
    if (ranges.isNotEmpty && from <= ranges.last.$2) {
      final last = ranges.removeLast();
      ranges.add((last.$1, last.$2 >= to ? last.$2 : to));
    } else {
      ranges.add((from, to));
    }
  }
  return ranges;
}

/// Returns the next audible position, or null when playback should end.
Duration? nextSleepPlaybackPosition(
  List<(Duration, Duration)> ranges,
  Duration position,
) {
  for (final (start, end) in ranges) {
    if (position < start) return start;
    if (position < end) return position;
  }
  return null;
}

/// Never amplify a sample beyond the output headroom.
double safeSleepPlaybackGain(double requested, double peak) =>
    requested > 1 && peak > 0 && requested * peak > 0.95
    ? 0.95 / peak
    : requested;

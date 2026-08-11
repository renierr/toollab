import 'dart:math' as math;

/// Overall verdict for a night.
enum SleepRating { good, fair, poor }

/// One thing that stood out, good or bad. The UI turns each into a sentence.
enum SleepFinding {
  allInRange,
  durationShort,
  durationLong,
  efficiencyLow,
  deepLow,
  deepHigh,
  remLow,
  remHigh,
  awakeHigh,
}

/// Scores a night against the ranges a standard adult sleep study reports:
/// 7-9 h total sleep, at least 85 % sleep efficiency, deep sleep 13-23 % and
/// REM 20-25 % of the time asleep, and under 30 minutes awake after falling
/// asleep. Anything outside those costs points; the ranges are population
/// guidance, not a diagnosis.
class SleepQuality {
  final Duration timeInBed;
  final Duration asleep;
  final Duration awake;
  final int awakenings;

  /// Null when the source stored no stages, so shares cannot be computed.
  final double? deepShare;
  final double? remShare;
  final double efficiency;
  final int score;
  final SleepRating rating;
  final List<SleepFinding> findings;

  const SleepQuality({
    required this.timeInBed,
    required this.asleep,
    required this.awake,
    required this.awakenings,
    required this.deepShare,
    required this.remShare,
    required this.efficiency,
    required this.score,
    required this.rating,
    required this.findings,
  });

  static const _awakeStages = {'awake', 'out_of_bed', 'awake_in_bed'};

  static SleepQuality? from({
    required List<Map<String, dynamic>> stages,
    required int startTime,
    required int endTime,
    int? asleepMinutes,
  }) {
    final timeInBed = Duration(milliseconds: endTime - startTime);
    if (timeInBed <= Duration.zero) return null;

    var awakeMs = 0;
    var deepMs = 0;
    var remMs = 0;
    var stagedMs = 0;
    var awakenings = 0;
    for (final stage in stages) {
      final type = (stage['type'] as String?)?.toLowerCase();
      final from = (stage['startTime'] as num?)?.toInt();
      final to = (stage['endTime'] as num?)?.toInt();
      if (type == null || from == null || to == null || to <= from) continue;
      final span = to - from;
      stagedMs += span;
      if (_awakeStages.contains(type)) {
        awakeMs += span;
        awakenings++;
      } else if (type == 'deep') {
        deepMs += span;
      } else if (type == 'rem') {
        remMs += span;
      }
    }

    // Stages win when present; otherwise the source's own asleep figure, and
    // failing that the whole span counts as sleep.
    final asleep = stagedMs > 0
        ? Duration(milliseconds: stagedMs - awakeMs)
        : Duration(minutes: asleepMinutes ?? timeInBed.inMinutes);
    if (asleep <= Duration.zero) return null;
    final efficiency = (asleep.inMilliseconds / timeInBed.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final hasStages = stagedMs > 0 && deepMs + remMs > 0;
    final deepShare = hasStages ? deepMs / asleep.inMilliseconds : null;
    final remShare = hasStages ? remMs / asleep.inMilliseconds : null;

    final findings = <SleepFinding>[];
    var score = 100;
    final hours = asleep.inMinutes / 60;
    if (hours < 6) {
      score -= 25;
      findings.add(SleepFinding.durationShort);
    } else if (hours < 7) {
      score -= 10;
      findings.add(SleepFinding.durationShort);
    } else if (hours > 10) {
      score -= 15;
      findings.add(SleepFinding.durationLong);
    }
    if (efficiency < 0.75) {
      score -= 20;
      findings.add(SleepFinding.efficiencyLow);
    } else if (efficiency < 0.85) {
      score -= 10;
      findings.add(SleepFinding.efficiencyLow);
    }
    if (deepShare != null) {
      if (deepShare < 0.13) {
        score -= 10;
        findings.add(SleepFinding.deepLow);
      } else if (deepShare > 0.23) {
        score -= 5;
        findings.add(SleepFinding.deepHigh);
      }
    }
    if (remShare != null) {
      if (remShare < 0.20) {
        score -= 10;
        findings.add(SleepFinding.remLow);
      } else if (remShare > 0.25) {
        score -= 5;
        findings.add(SleepFinding.remHigh);
      }
    }
    final awake = Duration(milliseconds: awakeMs);
    if (awake.inMinutes > 60) {
      score -= 15;
      findings.add(SleepFinding.awakeHigh);
    } else if (awake.inMinutes > 30) {
      score -= 5;
      findings.add(SleepFinding.awakeHigh);
    }
    if (findings.isEmpty) findings.add(SleepFinding.allInRange);

    score = math.max(0, score);
    return SleepQuality(
      timeInBed: timeInBed,
      asleep: asleep,
      awake: awake,
      awakenings: awakenings,
      deepShare: deepShare,
      remShare: remShare,
      efficiency: efficiency.toDouble(),
      score: score,
      rating: score >= 80
          ? SleepRating.good
          : score >= 60
          ? SleepRating.fair
          : SleepRating.poor,
      findings: findings,
    );
  }
}

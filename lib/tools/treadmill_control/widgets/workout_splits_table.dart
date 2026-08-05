import 'package:flutter/material.dart';

import '../treadmill_control_colors.dart';
import '../workout_details_stats.dart';

class WorkoutSplitsTable extends StatelessWidget {
  final List<WorkoutSplit> splits;
  final String kmHeader;
  final String timeHeader;
  final String paceHeader;
  final String heartRateHeader;

  const WorkoutSplitsTable({
    super.key,
    required this.splits,
    required this.kmHeader,
    required this.timeHeader,
    required this.paceHeader,
    required this.heartRateHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = splits.where((split) => !split.isPartial).toList();
    final fastest = full.isEmpty
        ? 0.0
        : full
              .map((split) => split.paceSecondsPerKm)
              .reduce((a, b) => a < b ? a : b);
    final slowest = full.isEmpty
        ? 0.0
        : full
              .map((split) => split.paceSecondsPerKm)
              .reduce((a, b) => a > b ? a : b);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.hintColor,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(width: 42, child: Text(kmHeader, style: headerStyle)),
            const Spacer(),
            SizedBox(
              width: 54,
              child: Text(
                timeHeader,
                textAlign: TextAlign.end,
                style: headerStyle,
              ),
            ),
            SizedBox(
              width: 58,
              child: Text(
                paceHeader,
                textAlign: TextAlign.end,
                style: headerStyle,
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                heartRateHeader,
                textAlign: TextAlign.end,
                style: headerStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final split in splits)
          _SplitRow(
            split: split,
            fastestPace: fastest,
            slowestPace: slowest,
            isFastest:
                !split.isPartial &&
                full.length > 1 &&
                split.paceSecondsPerKm == fastest,
          ),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  final WorkoutSplit split;
  final double fastestPace;
  final double slowestPace;
  final bool isFastest;

  const _SplitRow({
    required this.split,
    required this.fastestPace,
    required this.slowestPace,
    required this.isFastest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = slowestPace - fastestPace;
    final ratio = range <= 0
        ? 1.0
        : (1 - (split.paceSecondsPerKm - fastestPace) / range).clamp(0.15, 1.0);
    final mono = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              split.isPartial
                  ? split.endDistance.toStringAsFixed(2)
                  : split.endDistance.toStringAsFixed(0),
              style: mono?.copyWith(
                fontWeight: FontWeight.bold,
                color: split.isPartial ? theme.hintColor : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: split.isPartial ? ratio * 0.999 : ratio,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.outline.withValues(
                    alpha: 0.15,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    isFastest
                        ? TreadmillColors.greenMetric
                        : TreadmillColors.cyanMetric.withValues(
                            alpha: split.isPartial ? 0.4 : 0.75,
                          ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              formatWorkoutClock(split.seconds),
              textAlign: TextAlign.end,
              style: mono,
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              formatPace(split.paceSecondsPerKm),
              textAlign: TextAlign.end,
              style: mono?.copyWith(
                fontWeight: FontWeight.bold,
                color: isFastest ? TreadmillColors.greenMetric : null,
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              split.avgHeartRate > 0 ? '${split.avgHeartRate}' : '–',
              textAlign: TextAlign.end,
              style: mono?.copyWith(color: theme.hintColor),
            ),
          ),
        ],
      ),
    );
  }
}

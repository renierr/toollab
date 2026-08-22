import 'package:flutter/material.dart';

class WorkoutLegendEntry {
  final String label;
  final Color color;

  const WorkoutLegendEntry(this.label, this.color);
}

class WorkoutChartLegend extends StatelessWidget {
  final List<WorkoutLegendEntry> entries;

  const WorkoutChartLegend({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: entries
          .map(
            (entry) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

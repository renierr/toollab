import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/sparkline.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  final bool compact;

  /// Recent readings of this metric, drawn as a trend line behind the value.
  final List<double?>? trend;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
    this.compact = false,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = this.trend;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (trend != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: compact ? 42 : 52,
              child: Sparkline(values: trend, color: color),
            ),
          Padding(
            padding: EdgeInsets.all(compact ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: compact ? 18 : 24),
                SizedBox(height: compact ? 8 : 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (compact
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        unit!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  final List<MetricTile> children;
  final int wideColumns;

  const MetricGrid({super.key, required this.children, this.wideColumns = 4});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 500 ? 2 : wideColumns;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

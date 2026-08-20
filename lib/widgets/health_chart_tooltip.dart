import 'package:flutter/material.dart';

/// One readout line inside a chart tooltip.
typedef HealthChartReading = ({Color color, String text});

/// The readout every health chart shows under the cursor or finger.
///
/// Trend, day and session charts all point at the same widget so a value reads
/// the same wherever it is picked up.
class HealthChartTooltip extends StatelessWidget {
  final String title;

  /// Optional dot plus label next to the title, for a band the marker sits in.
  final HealthChartReading? titleTag;
  final List<HealthChartReading> readings;

  const HealthChartTooltip({
    super.key,
    required this.title,
    this.titleTag,
    required this.readings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = titleTag;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.labelSmall),
                if (tag != null) ...[
                  const SizedBox(width: 5),
                  HealthChartDot(color: tag.color),
                  const SizedBox(width: 3),
                  Text(tag.text, style: theme.textTheme.labelSmall),
                ],
              ],
            ),
            for (final reading in readings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HealthChartDot(color: reading.color),
                    const SizedBox(width: 4),
                    Text(reading.text, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HealthChartDot extends StatelessWidget {
  final Color color;

  const HealthChartDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

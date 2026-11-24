import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/widgets/sparkline.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  final bool compact;

  /// A secondary figure shown below the label.
  final String? detail;

  /// Explains the metric behind an info icon; tap shows it on touch screens.
  final String? info;

  /// Recent readings of this metric, drawn as a trend line behind the value.
  final List<double?>? trend;

  /// Opens details; the tile then shows a chevron.
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
    this.compact = false,
    this.detail,
    this.info,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = this.trend;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  Row(
                    children: [
                      Icon(icon, color: color, size: compact ? 18 : 24),
                      const Spacer(),
                      if (info != null)
                        Tooltip(
                          message: info,
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: const Duration(seconds: 10),
                          child: Icon(
                            Icons.info_outline,
                            size: compact ? 16 : 20,
                            color: theme.hintColor,
                          ),
                        ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right,
                          size: compact ? 18 : 22,
                          color: theme.hintColor,
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          value,
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
      final columns = constraints.maxWidth < 240
          ? 1
          : constraints.maxWidth < 500
          ? 2
          : wideColumns;
      // Rows instead of a Wrap so a tile whose value wraps stretches its row.
      return Column(
        spacing: 12,
        children: [
          for (var start = 0; start < children.length; start += columns)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  for (var i = start; i < start + columns; i++)
                    Expanded(
                      child: i < children.length
                          ? children[i]
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

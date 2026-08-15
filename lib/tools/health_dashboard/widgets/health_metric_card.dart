import 'package:flutter/material.dart';

class HealthMetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const HealthMetricCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 148,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: _MetricValue(value: value),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MetricValue extends StatelessWidget {
  final String value;

  const _MetricValue({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = RegExp(
      r'^(.*?)(?:\s+)(km|kcal|bpm|ms|kg|%|rpm)$|^(.*?)(h(?: \d+m)?|m)$',
    ).firstMatch(value);
    if (match == null) {
      return Text(value, style: theme.textTheme.headlineSmall);
    }
    final number = match.group(1) ?? match.group(3)!;
    final unit = match.group(2) ?? match.group(4)!;
    return Text.rich(
      TextSpan(
        text: number,
        style: theme.textTheme.headlineSmall,
        children: [
          TextSpan(
            text: ' $unit',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

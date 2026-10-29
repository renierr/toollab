import 'package:flutter/material.dart';

import '../depot_format.dart';

class DepotShareEntry {
  final String label;
  final double value;
  final Color color;

  const DepotShareEntry({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// A stacked bar with a legend row per category, showing money and share.
class DepotShareBreakdown extends StatelessWidget {
  final String title;
  final List<DepotShareEntry> entries;
  final DepotFormat format;

  const DepotShareBreakdown({
    super.key,
    required this.title,
    required this.entries,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries)
                  Expanded(
                    flex: (entry.value / total * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: entry.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: entry.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.label, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  format.percent(entry.value / total * 100, signed: false),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(format.money(entry.value)),
              ],
            ),
          ),
      ],
    );
  }
}

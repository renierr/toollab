import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../config.dart';

typedef PaperlessCountEntry = ({String label, int count, Color? color});

/// Ranked counts as bars scaled to the largest entry.
class PaperlessCountCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<PaperlessCountEntry> entries;

  const PaperlessCountCard({
    super.key,
    required this.icon,
    required this.title,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final max = entries.fold(0, (m, e) => e.count > m ? e.count : m);
    return InfoCard(
      icon: icon,
      title: title,
      child: Column(
        children: [
          for (final entry in entries)
            _CountRow(entry: entry, fraction: max == 0 ? 0 : entry.count / max),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final PaperlessCountEntry entry;
  final double fraction;

  const _CountRow({required this.entry, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.count}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: entry.color ?? PaperlessTool.config.accentColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

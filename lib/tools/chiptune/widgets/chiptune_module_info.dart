import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../chiptune_colors.dart';
import '../engine/module.dart';

/// Summary card for the loaded module: format, title and key metrics.
class ChiptuneModuleInfo extends StatelessWidget {
  final ModuleFile module;
  const ChiptuneModuleInfo({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instrumentCount = module.instruments
        .where((i) => i.samples.isNotEmpty)
        .length;

    return InfoCard(
      icon: Icons.music_note_outlined,
      title: module.title.isEmpty ? 'Untitled' : module.title,
      titleColor: ChiptuneColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(label: module.type, color: ChiptuneColors.accent),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Metric(label: 'Channels', value: '${module.channels}'),
              _Metric(label: 'Patterns', value: '${module.patterns.length}'),
              _Metric(label: 'Orders', value: '${module.sequence.length}'),
              _Metric(label: 'Instruments', value: '$instrumentCount'),
              _Metric(label: 'BPM', value: '${module.defaultBpm}'),
              _Metric(label: 'Speed', value: '${module.defaultSpeed}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tip: most module collections live at modarchive.org',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ChiptuneColors.accentBright,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

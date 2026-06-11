import 'package:flutter/material.dart';

import '../engine/module.dart';

/// Collapsible list of the module's instruments and their sample sizes.
class ChiptuneSampleList extends StatefulWidget {
  final ModuleFile module;
  const ChiptuneSampleList({super.key, required this.module});

  @override
  State<ChiptuneSampleList> createState() => _ChiptuneSampleListState();
}

class _ChiptuneSampleListState extends State<ChiptuneSampleList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instruments = widget.module.instruments
        .where((i) => i.samples.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Instruments (${instruments.length})',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...instruments.asMap().entries.map((e) {
            final ins = e.value;
            final sample = ins.samples.first;
            final kb = (sample.length / 1024).round();
            final looped = sample.loopLength > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${e.key + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ins.name.isEmpty ? '(unnamed)' : ins.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${kb}KB${looped ? ' · loop' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

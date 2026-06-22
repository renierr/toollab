import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../file_converter_state.dart';

/// Chips of the formats the loaded file can be converted into.
class FormatTargetSelector extends StatelessWidget {
  const FormatTargetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<FileConverterState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fileConverterConvertTo,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in state.targets)
              ToolChip(
                icon: format.icon,
                label: format.label(l10n),
                selected: state.selectedTarget == format,
                onTap: () =>
                    context.read<FileConverterState>().selectTarget(format),
              ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../file_converter_state.dart';
import 'format_target_selector.dart';

/// Body shown once a file is loaded: source info, target picker, convert action.
class ConversionPanel extends StatelessWidget {
  final TempFileScope scope;

  const ConversionPanel({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<FileConverterState>();
    final inputFormat = state.inputFormat;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoCard(
            icon: inputFormat?.icon ?? Icons.insert_drive_file_outlined,
            title: state.inputName ?? '',
            child: Text(
              inputFormat != null
                  ? inputFormat.label(l10n)
                  : l10n.fileConverterUnsupported,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!state.isSupported)
            Text(
              l10n.fileConverterUnsupported,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.statusRed,
              ),
            )
          else ...[
            const FormatTargetSelector(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isConverting || state.selectedTarget == null
                  ? null
                  : () => context.read<FileConverterState>().convert(
                      context,
                      scope,
                    ),
              icon: state.isConverting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_alt),
              label: Text(
                state.isConverting
                    ? l10n.fileConverterConverting
                    : l10n.fileConverterConvert,
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.fileConverterError(state.error!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.statusRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

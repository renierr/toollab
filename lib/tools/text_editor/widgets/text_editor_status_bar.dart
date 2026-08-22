import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';

class TextEditorStatusBar extends StatelessWidget {
  final TextEditorState state;

  const TextEditorStatusBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = state.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: error != null
            ? AppTheme.statusRed.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          if (state.isSaving || state.isUploading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              error ??
                  _statusLine(l10n, state, remoteLabel: l10n.textEditorRemote),
              style: theme.textTheme.bodySmall?.copyWith(
                color: error != null ? AppTheme.statusRed : null,
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLine(
    AppLocalizations l10n,
    TextEditorState state, {
    required String remoteLabel,
  }) {
    final parts = <String>[
      if (state.dirty) l10n.textEditorUnsavedChanges,
      if (state.fileName != null) state.fileName!,
      state.encodingLabel,
      if (state.languageKey != null && state.highlightEnabled)
        state.languageKey!.toUpperCase(),
      if (state.isRemote)
        '$remoteLabel: ${state.origin!.protocol.toUpperCase()} • '
            '${state.origin!.host}',
    ];
    return parts.join('  •  ');
  }
}

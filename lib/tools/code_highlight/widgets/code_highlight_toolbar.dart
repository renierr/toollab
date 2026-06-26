import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import '../code_highlight_state.dart';

class CodeHighlightToolbar extends StatelessWidget {
  final VoidCallback onReset;

  const CodeHighlightToolbar({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<CodeHighlightState>();
    final isWide = MediaQuery.of(context).size.width > 720;

    final infoPanel = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.fileName ?? l10n.codeHighlightEditorTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.codeHighlightLanguage}: ${state.language.toUpperCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final langDropdown = Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.language,
                dropdownColor: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                items: [...state.supportedLanguages, 'plain']
                    .map(
                      (lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(
                          lang.toUpperCase(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    state.setLanguage(val);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    final actionsWrap = Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.close, size: 18),
          label: Text(l10n.commonClose),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.statusRed,
            side: const BorderSide(color: AppTheme.statusRed),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(flex: 4, child: infoPanel),
            const SizedBox(width: 16),
            langDropdown,
            const SizedBox(width: 16),
            actionsWrap,
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            infoPanel,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: langDropdown),
                const SizedBox(width: 8),
                actionsWrap,
              ],
            ),
          ],
        ),
      );
    }
  }
}

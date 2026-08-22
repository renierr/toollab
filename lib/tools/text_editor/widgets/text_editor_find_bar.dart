import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

class TextEditorFindBar extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;

  const TextEditorFindBar({super.key, required this.controller});

  static const _rowHeight = 44.0;

  @override
  Size get preferredSize => controller.value == null
      ? const Size(0, 0)
      : Size(
          double.infinity,
          controller.value!.replaceMode ? _rowHeight * 2 : _rowHeight,
        );

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: controller.findInputController,
                      focusNode: controller.findInputFocusNode,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: l10n.textEditorFindHint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                _ToggleTextButton(
                  label: 'Aa',
                  checked: value.option.caseSensitive,
                  onPressed: controller.toggleCaseSensitive,
                ),
                _ToggleTextButton(
                  label: '.*',
                  checked: value.option.regex,
                  onPressed: controller.toggleRegex,
                ),
                Flexible(
                  child: Text(
                    value.result == null
                        ? l10n.textEditorFindNoResults
                        : '${value.result!.index + 1}/${value.result!.matches.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ),
                IconButton(
                  tooltip: l10n.textEditorFindPrevious,
                  onPressed: value.result == null
                      ? null
                      : controller.previousMatch,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: l10n.textEditorFindNext,
                  onPressed: value.result == null ? null : controller.nextMatch,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
            if (value.replaceMode) ...[
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        controller: controller.replaceInputController,
                        focusNode: controller.replaceInputFocusNode,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: l10n.textEditorReplaceHint,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.textEditorReplaceOne,
                    onPressed: value.result == null
                        ? null
                        : controller.replaceMatch,
                    icon: const Icon(Icons.find_replace),
                  ),
                  IconButton(
                    tooltip: l10n.textEditorReplaceAll,
                    onPressed: value.result == null
                        ? null
                        : controller.replaceAllMatches,
                    icon: const Icon(Icons.done_all),
                  ),
                ],
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: controller.toggleMode,
                  icon: Icon(
                    value.replaceMode ? Icons.search : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(
                    value.replaceMode
                        ? l10n.textEditorFindMode
                        : l10n.textEditorReplaceMode,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: controller.close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTextButton extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onPressed;

  const _ToggleTextButton({
    required this.label,
    required this.checked,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: checked
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: checked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

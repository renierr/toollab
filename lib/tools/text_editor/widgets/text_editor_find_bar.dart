import 'dart:async';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

class TextEditorFindBar extends StatefulWidget implements PreferredSizeWidget {
  final CodeFindController controller;

  const TextEditorFindBar({super.key, required this.controller});

  @override
  State<TextEditorFindBar> createState() => _TextEditorFindBarState();

  @override
  Size get preferredSize => controller.value == null
      ? const Size(0, 0)
      : Size(
          double.infinity,
          controller.value!.replaceMode ? _rowHeight * 2 : _rowHeight,
        );

  static const _rowHeight = 44.0;
}

class _TextEditorFindBarState extends State<TextEditorFindBar> {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final TextEditingController _findInput = TextEditingController();
  Timer? _debounce;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _findInput.value = widget.controller.findInputController.value;
    _findInput.addListener(_onLocalChanged);
    widget.controller.findInputController.addListener(_syncFromInternal);
  }

  // re_editor searches on every keystroke via its own listener; only push the
  // final text after the debounce so large documents are searched once.
  void _onLocalChanged() {
    if (_syncing) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      final internal = widget.controller.findInputController;
      if (internal.text == _findInput.text) return;
      _syncing = true;
      internal.value = TextEditingValue(
        text: _findInput.text,
        selection: TextSelection.collapsed(offset: _findInput.text.length),
      );
      _syncing = false;
    });
  }

  void _syncFromInternal() {
    if (_syncing) return;
    final internal = widget.controller.findInputController;
    if (internal.text == _findInput.text) return;
    _syncing = true;
    _findInput.value = internal.value;
    _syncing = false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.findInputController.removeListener(_syncFromInternal);
    _findInput.dispose();
    super.dispose();
  }

  static bool _hasResults(CodeFindValue value) =>
      !value.searching &&
      value.result != null &&
      value.result!.matches.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    if (value == null) return const SizedBox.shrink();
    final controller = widget.controller;
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
                      controller: _findInput,
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
                  child: value.searching
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.textEditorFindSearching,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ],
                        )
                      : Text(
                          value.result == null || value.result!.matches.isEmpty
                              ? l10n.textEditorFindNoResults
                              : '${value.result!.index + 1}/${value.result!.matches.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                ),
                IconButton(
                  tooltip: l10n.textEditorFindPrevious,
                  onPressed: !_hasResults(value)
                      ? null
                      : controller.previousMatch,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: l10n.textEditorFindNext,
                  onPressed: !_hasResults(value) ? null : controller.nextMatch,
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
                    onPressed: !_hasResults(value)
                        ? null
                        : controller.replaceMatch,
                    icon: const Icon(Icons.find_replace),
                  ),
                  IconButton(
                    tooltip: l10n.textEditorReplaceAll,
                    onPressed: !_hasResults(value)
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

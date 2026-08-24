import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'package:tool_lab/tools/text_editor/text_editor_languages.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_find_bar.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_selection_toolbar.dart';

class TextEditorSurface extends StatelessWidget {
  /// Editor line height factor; the gutter reuses it so line numbers keep the
  /// same line box as the code text and stay aligned at any font size.
  static const _lineHeight = 1.4;
  static const _numberScale = 0.85;

  final TextEditorState state;

  const TextEditorSurface({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberStyle = TextStyle(
      fontSize: state.fontSize * _numberScale,
      height: _lineHeight / _numberScale,
      fontFamilyFallback: const ['Consolas', 'Courier New', 'monospace'],
    );
    return CodeEditor(
      controller: state.controller,
      scrollController: state.scrollController,
      findController: state.findController,
      wordWrap: state.wordWrap,
      style: CodeEditorStyle(
        fontSize: state.fontSize,
        fontHeight: _lineHeight,
        fontFamilyFallback: const ['Consolas', 'Courier New', 'monospace'],
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withValues(alpha: 0.25),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        cursorLineColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        codeTheme: state.highlightEnabled && state.languageKey != null
            ? TextEditorLanguages.themeFor(state.languageKey!, theme.brightness)
            : null,
      ),
      indicatorBuilder:
          (context, editingController, chunkController, notifier) => Row(
            children: [
              DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                textStyle: numberStyle.copyWith(
                  color: theme.colorScheme.outline,
                ),
                focusedTextStyle: numberStyle.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              DefaultCodeChunkIndicator(
                width: 18,
                controller: chunkController,
                notifier: notifier,
              ),
            ],
          ),
      findBuilder: (context, findController, readOnly) =>
          TextEditorFindBar(controller: findController),
      toolbarController: const TextEditorSelectionToolbar(),
    );
  }
}

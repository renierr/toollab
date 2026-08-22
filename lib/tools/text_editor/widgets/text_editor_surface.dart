import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'package:tool_lab/tools/text_editor/text_editor_languages.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_find_bar.dart';

class TextEditorSurface extends StatelessWidget {
  final TextEditorState state;

  const TextEditorSurface({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CodeEditor(
      controller: state.controller,
      scrollController: state.scrollController,
      findController: state.findController,
      wordWrap: state.wordWrap,
      style: CodeEditorStyle(
        fontSize: state.fontSize,
        fontFamilyFallback: const ['Consolas', 'Courier New', 'monospace'],
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withValues(alpha: 0.25),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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
                textStyle: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: state.fontSize * 0.85,
                ),
                focusedTextStyle: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: state.fontSize * 0.85,
                ),
              ),
            ],
          ),
      findBuilder: (context, findController, readOnly) =>
          TextEditorFindBar(controller: findController),
    );
  }
}

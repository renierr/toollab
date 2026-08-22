import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:re_editor/re_editor.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';

class TextEditorToolbar extends StatelessWidget {
  final TextEditorState state;

  const TextEditorToolbar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 0,
        children: [
          _UndoRedoButtons(controller: state.controller),
          IconButton(
            tooltip: l10n.textEditorFontSmaller,
            onPressed: () => state.setFontSize(state.fontSize - 1),
            icon: const Icon(Icons.text_decrease_outlined),
          ),
          IconButton(
            tooltip: l10n.textEditorFontLarger,
            onPressed: () => state.setFontSize(state.fontSize + 1),
            icon: const Icon(Icons.text_increase_outlined),
          ),
          const VerticalDivider(width: 8),
          FilterChip(
            label: Text(l10n.textEditorWordWrap),
            selected: state.wordWrap,
            onSelected: state.setWordWrap,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.textEditorSyntaxHighlight),
            selected: state.highlightEnabled && state.hasHighlightableLanguage,
            onSelected: state.hasHighlightableLanguage
                ? (value) => state.setHighlightEnabled(value)
                : null,
          ),
        ],
      ),
    );
  }
}

/// re_editor fires controller notifications synchronously while the editor
/// mounts, so rebuilds are deferred to the end of the frame.
class _UndoRedoButtons extends StatefulWidget {
  final CodeLineEditingController controller;

  const _UndoRedoButtons({required this.controller});

  @override
  State<_UndoRedoButtons> createState() => _UndoRedoButtonsState();
}

class _UndoRedoButtonsState extends State<_UndoRedoButtons> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_UndoRedoButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.textEditorUndo,
          onPressed: widget.controller.canUndo ? widget.controller.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: l10n.textEditorRedo,
          onPressed: widget.controller.canRedo ? widget.controller.redo : null,
          icon: const Icon(Icons.redo),
        ),
      ],
    );
  }
}

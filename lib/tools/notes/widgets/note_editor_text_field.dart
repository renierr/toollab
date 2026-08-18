import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class NoteEditorTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController? scrollController;
  final bool isMonospace;

  const NoteEditorTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.scrollController,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        scrollController: scrollController,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        clipBehavior: Clip.none,
        style: TextStyle(
          fontFamily: isMonospace ? 'monospace' : null,
          fontFamilyFallback: isMonospace
              ? const ['Courier', 'Consolas']
              : null,
          fontSize: 16,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: l10n.notesEditorHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class NoteEditorTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isMonospace;

  const NoteEditorTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: isMonospace ? 'monospace' : null,
          fontSize: 14,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: l10n.notesEditorHint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

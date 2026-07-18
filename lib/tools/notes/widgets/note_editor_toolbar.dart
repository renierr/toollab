import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class NoteEditorToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onStrikethrough;
  final VoidCallback onH1;
  final VoidCallback onH2;
  final VoidCallback onH3;
  final VoidCallback onList;
  final VoidCallback onTodo;
  final VoidCallback onLink;
  final VoidCallback onCode;
  final VoidCallback onCodeBlock;
  final VoidCallback onImage;

  const NoteEditorToolbar({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onStrikethrough,
    required this.onH1,
    required this.onH2,
    required this.onH3,
    required this.onList,
    required this.onTodo,
    required this.onLink,
    required this.onCode,
    required this.onCodeBlock,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = [
      (Icons.format_bold, l10n.notesToolbarBold, onBold),
      (Icons.format_italic, l10n.notesToolbarItalic, onItalic),
      (
        Icons.format_strikethrough,
        l10n.notesToolbarStrikethrough,
        onStrikethrough,
      ),
      (Icons.looks_one, l10n.notesToolbarH1, onH1),
      (Icons.looks_two, l10n.notesToolbarH2, onH2),
      (Icons.looks_3, l10n.notesToolbarH3, onH3),
      (Icons.format_list_bulleted, l10n.notesToolbarList, onList),
      (Icons.check_box_outlined, l10n.notesToolbarTodo, onTodo),
      (Icons.link, l10n.notesToolbarLink, onLink),
      (Icons.code, l10n.notesToolbarCode, onCode),
      (Icons.integration_instructions, l10n.notesToolbarCodeBlock, onCodeBlock),
      (Icons.add_photo_alternate_outlined, l10n.notesToolbarImage, onImage),
    ];

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      width: double.infinity,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: items.map((item) {
          return Tooltip(
            message: item.$2,
            child: IconButton(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              icon: Icon(item.$1, size: 20),
              onPressed: item.$3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }).toList(),
      ),
    );
  }
}

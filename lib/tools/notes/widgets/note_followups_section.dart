import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_thread_export.dart';
import 'package:tool_lab/tools/notes/widgets/note_thread_tree.dart';

/// Timeline of a note's follow-ups plus the entry point to add one.
class NoteFollowUpsSection extends StatelessWidget {
  final NoteThreadNode? node;
  final Color accentColor;
  final ValueChanged<NoteThreadNode> onOpenNote;
  final VoidCallback onAddFollowUp;

  const NoteFollowUpsSection({
    super.key,
    required this.node,
    required this.accentColor,
    required this.onOpenNote,
    required this.onAddFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final children = node?.children ?? const <NoteThreadNode>[];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.notesFollowUpsTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.notesFollowUpCount(children.length),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onAddFollowUp,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.notesAddFollowUp),
                style: TextButton.styleFrom(foregroundColor: accentColor),
              ),
              if (children.isNotEmpty)
                TextButton.icon(
                  onPressed: () => exportThreadPdf(context, node!),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(l10n.notesExportThreadPdf),
                  style: TextButton.styleFrom(foregroundColor: accentColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (children.isEmpty)
            Text(
              l10n.notesNoFollowUps,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            NoteThreadTree(
              nodes: children,
              accentColor: accentColor,
              onTap: onOpenNote,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_title.dart';
import 'package:tool_lab/tools/notes/widgets/note_thread_tree.dart';

/// Breadcrumb plus collapsible outline of the whole thread a note belongs to.
class NoteThreadOutline extends StatefulWidget {
  final NoteThread thread;
  final String currentShortId;
  final Color accentColor;
  final ValueChanged<NoteThreadNode> onOpenNote;

  const NoteThreadOutline({
    super.key,
    required this.thread,
    required this.currentShortId,
    required this.accentColor,
    required this.onOpenNote,
  });

  @override
  State<NoteThreadOutline> createState() => _NoteThreadOutlineState();
}

class _NoteThreadOutlineState extends State<NoteThreadOutline> {
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final root = widget.thread.rootOf(widget.currentShortId);
    if (root == null) return const SizedBox.shrink();

    final current = widget.thread.byShortId[widget.currentShortId];
    final orphanHint = current?.orphan == true
        ? Row(
            children: [
              Icon(
                Icons.link_off,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.notesOrphanHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        : null;

    final total = root.descendantCount + 1;
    if (total < 2) return orphanHint ?? const SizedBox.shrink();

    final ancestors = widget.thread.ancestorsOf(widget.currentShortId);
    final expanded = _expanded ?? total <= 12;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?orphanHint,
          if (ancestors.isNotEmpty)
            _Breadcrumb(
              ancestors: ancestors,
              accentColor: widget.accentColor,
              onOpenNote: widget.onOpenNote,
            ),
          InkWell(
            onTap: () => setState(() => _expanded = !expanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: widget.accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.notesThreadTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.notesThreadCount(total),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 4),
            NoteThreadTree(
              nodes: [root],
              currentShortId: widget.currentShortId,
              accentColor: widget.accentColor,
              onTap: widget.onOpenNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final List<NoteThreadNode> ancestors;
  final Color accentColor;
  final ValueChanged<NoteThreadNode> onOpenNote;

  const _Breadcrumb({
    required this.ancestors,
    required this.accentColor,
    required this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          for (final node in ancestors) ...[
            InkWell(
              onTap: () => onOpenNote(node),
              child: Text(
                noteTitle(node.note.content, fallback: l10n.notesUntitledNote),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_title.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Picks the note a given note should hang under. Candidates exclude the note
/// itself and its own subtree, so a pick can never build a cycle.
class NoteParentPickerDialog extends StatefulWidget {
  final NoteThread thread;
  final String shortId;

  const NoteParentPickerDialog({
    super.key,
    required this.thread,
    required this.shortId,
  });

  static Future<String?> show({
    required BuildContext context,
    required NoteThread thread,
    required String shortId,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => NoteParentPickerDialog(thread: thread, shortId: shortId),
    );
  }

  @override
  State<NoteParentPickerDialog> createState() => _NoteParentPickerDialogState();
}

class _NoteParentPickerDialogState extends State<NoteParentPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final node = widget.thread.byShortId[widget.shortId];
    final excluded = {
      widget.shortId,
      ...?node?.flatten().map((n) => n.shortId),
    };
    final needle = _query.trim().toLowerCase();

    final candidates =
        widget.thread.byShortId.values
            .where((n) => !excluded.contains(n.shortId))
            .where(
              (n) =>
                  needle.isEmpty ||
                  (n.note['content'] as String? ?? '').toLowerCase().contains(
                    needle,
                  ),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ResponsiveAlertDialog(
      title: Text(l10n.notesAttachPickerTitle),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.notesAttachSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final candidate = candidates[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      candidate.depth == 0
                          ? Icons.article_outlined
                          : Icons.subdirectory_arrow_right,
                      size: 20,
                      color: AppTheme.accentTeal,
                    ),
                    title: Text(
                      noteTitle(
                        candidate.note['content'] as String? ?? '',
                        fallback: l10n.notesUntitledNote,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      FormatHelper.epoch(
                        candidate.updatedAt,
                        style: DateStyle.dateOnly,
                      ),
                      style: theme.textTheme.labelSmall,
                    ),
                    onTap: () => Navigator.of(context).pop(candidate.shortId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

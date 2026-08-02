import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/widgets/note_card.dart';

class NotesList extends StatefulWidget {
  final List<Map<String, dynamic>> notes;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const NotesList({
    super.key,
    required this.notes,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<NotesList> {
  final Map<String, bool> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (widget.notes.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 72,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.notesEmptyTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.notesEmptyDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = _groupNotes();
    final isGrid = MediaQuery.sizeOf(context).width >= 600;

    return CustomScrollView(
      slivers: [
        for (var index = 0; index < groups.length; index++) ...[
          SliverToBoxAdapter(
            child: _NotesArchiveHeader(
              title: DateFormat.yMMMM(
                l10n.localeName,
              ).format(groups[index].date),
              count: groups[index].notes.length,
              expanded: _expandedGroups[groups[index].key] ?? index == 0,
              onTap: () {
                setState(() {
                  _expandedGroups[groups[index].key] =
                      !(_expandedGroups[groups[index].key] ?? index == 0);
                });
              },
            ),
          ),
          if (_expandedGroups[groups[index].key] ?? index == 0)
            if (isGrid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 250,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, noteIndex) => _NoteListCard(
                      note: groups[index].notes[noteIndex],
                      onTap: widget.onTap,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
                    childCount: groups[index].notes.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                sliver: SliverList.builder(
                  itemCount: groups[index].notes.length,
                  itemBuilder: (context, noteIndex) => _NoteListCard(
                    note: groups[index].notes[noteIndex],
                    onTap: widget.onTap,
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                ),
              ),
        ],
      ],
    );
  }

  List<_NotesArchiveGroup> _groupNotes() {
    final grouped = <String, _NotesArchiveGroup>{};
    for (final note in widget.notes) {
      final updatedAt = note['updated_at'] as int? ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(updatedAt);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      grouped
          .putIfAbsent(
            key,
            () => _NotesArchiveGroup(key: key, date: date, notes: []),
          )
          .notes
          .add(note);
    }
    return grouped.values.toList();
  }
}

class _NotesArchiveGroup {
  final String key;
  final DateTime date;
  final List<Map<String, dynamic>> notes;

  const _NotesArchiveGroup({
    required this.key,
    required this.date,
    required this.notes,
  });
}

class _NotesArchiveHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _NotesArchiveHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l10n.notesArchiveEntryCount(count),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteListCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _NoteListCard({
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return NoteCard(
      note: note,
      onTap: () => onTap(note),
      onEdit: () => onEdit(note),
      onDelete: () => onDelete(note),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/note_thread.dart';
import 'package:tool_lab/tools/notes/note_thread_export.dart';
import 'package:tool_lab/tools/notes/note_title.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/notes/widgets/note_card.dart';
import 'package:tool_lab/tools/notes/widgets/note_thread_tree.dart';

class NotesList extends StatefulWidget {
  /// Flat, query-filtered notes — used while searching.
  final List<Map<String, dynamic>> notes;

  /// Thread roots to render when not searching.
  final List<NoteThreadNode> roots;
  final NoteThread thread;
  final bool searchMode;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onAddFollowUp;
  final ValueChanged<Map<String, dynamic>> onAttach;
  final ValueChanged<Map<String, dynamic>> onDetach;

  const NotesList({
    super.key,
    required this.notes,
    required this.roots,
    required this.thread,
    required this.searchMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onAddFollowUp,
    required this.onAttach,
    required this.onDetach,
  });

  @override
  State<NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<NotesList> {
  final Map<String, bool> _expandedGroups = {};
  final Set<String> _expandedThreads = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final isEmpty = widget.searchMode
        ? widget.notes.isEmpty
        : widget.roots.isEmpty;
    if (isEmpty) {
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

    final groups = _groupEntries();
    final isGrid = MediaQuery.sizeOf(context).width >= 600;

    return CustomScrollView(
      slivers: [
        for (var index = 0; index < groups.length; index++) ...[
          SliverToBoxAdapter(
            child: _NotesArchiveHeader(
              title: DateFormat.yMMMM(
                l10n.localeName,
              ).format(groups[index].date),
              count: groups[index].entries.length,
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
                    (context, entryIndex) =>
                        _buildCard(groups[index].entries[entryIndex]),
                    childCount: groups[index].entries.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                sliver: SliverList.builder(
                  itemCount: groups[index].entries.length,
                  itemBuilder: (context, entryIndex) => _buildEntry(
                    groups[index].entries[entryIndex],
                    expandable: true,
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildEntry(_NoteEntry entry, {required bool expandable}) {
    final node = entry.node;
    final expanded = node != null && _expandedThreads.contains(node.shortId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(entry, expandable: expandable),
        if (expanded && node.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: NoteThreadTree(
              nodes: node.children,
              accentColor: AppTheme.accentTeal,
              dense: true,
              onTap: (child) => widget.onTap(child.note),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(_NoteEntry entry, {bool expandable = false}) {
    final node = entry.node;
    final followUps = node?.descendantCount ?? 0;
    return NoteCard(
      note: entry.note,
      breadcrumb: entry.breadcrumb,
      followUpCount: followUps,
      followUpsExpanded:
          node != null && _expandedThreads.contains(node.shortId),
      // Cards in the grid have a fixed height, so there the thread opens in a
      // popover anchored to the badge instead of expanding in place.
      onFollowUpsTap: followUps == 0 || node == null
          ? null
          : expandable
          ? (_) => setState(() {
              if (!_expandedThreads.remove(node.shortId)) {
                _expandedThreads.add(node.shortId);
              }
            })
          : (badgeContext) => _showThreadPopover(badgeContext, node),
      onTap: () => widget.onTap(entry.note),
      onEdit: () => widget.onEdit(entry.note),
      onDelete: () => widget.onDelete(entry.note),
      onExportThreadPdf: node == null
          ? null
          : () => exportThreadPdf(context, node),
      onAddFollowUp: () => widget.onAddFollowUp(entry.note),
      onAttach: () => widget.onAttach(entry.note),
      onDetach: () => widget.onDetach(entry.note),
    );
  }

  Future<void> _showThreadPopover(
    BuildContext badgeContext,
    NoteThreadNode node,
  ) async {
    final box = badgeContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(badgeContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final availableWidth = MediaQuery.sizeOf(badgeContext).width - 32;
    final popupWidth = availableWidth.clamp(0.0, 520.0);
    final selected = await showMenu<NoteThreadNode>(
      context: badgeContext,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<NoteThreadNode>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: popupWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: NoteThreadTree(
                nodes: node.children,
                accentColor: AppTheme.accentTeal,
                dense: true,
                onTap: (child) => Navigator.of(badgeContext).pop(child),
              ),
            ),
          ),
        ),
      ],
    );
    if (selected != null) widget.onTap(selected.note);
  }

  List<_NotesArchiveGroup> _groupEntries() {
    final l10n = AppLocalizations.of(context);
    final entries = widget.searchMode
        ? [
            for (final note in widget.notes)
              _NoteEntry(
                note: note,
                node: widget.thread.nodeForShortId(note['short_id'] as String?),
                breadcrumb: [
                  for (final ancestor in widget.thread.ancestorsOf(
                    note['short_id'] as String? ?? '',
                  ))
                    noteTitle(
                      ancestor.note['content'] as String? ?? '',
                      fallback: l10n.notesUntitledNote,
                    ),
                ],
                timestamp: note['updated_at'] as int? ?? 0,
              ),
          ]
        : [
            for (final root in widget.roots)
              _NoteEntry(
                note: root.note,
                node: root,
                breadcrumb: const [],
                timestamp: root.threadUpdatedAt,
              ),
          ];

    final grouped = <String, _NotesArchiveGroup>{};
    for (final entry in entries) {
      final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      grouped
          .putIfAbsent(
            key,
            () => _NotesArchiveGroup(key: key, date: date, entries: []),
          )
          .entries
          .add(entry);
    }
    return grouped.values.toList();
  }
}

class _NoteEntry {
  final Map<String, dynamic> note;
  final NoteThreadNode? node;
  final List<String> breadcrumb;
  final int timestamp;

  const _NoteEntry({
    required this.note,
    required this.node,
    required this.breadcrumb,
    required this.timestamp,
  });
}

class _NotesArchiveGroup {
  final String key;
  final DateTime date;
  final List<_NoteEntry> entries;

  const _NotesArchiveGroup({
    required this.key,
    required this.date,
    required this.entries,
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

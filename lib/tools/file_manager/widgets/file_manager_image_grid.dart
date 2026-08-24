import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_date_groups.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_path_labels.dart';

const double _referenceTileExtent = 160;
const double _minTileExtent = 72;
const int _maxColumns = 16;
const double _spacing = 8;
const double _gridPadding = 8;

class FileManagerImageGrid extends StatefulWidget {
  final List<FileManagerEntry> entries;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<String> onOpenFolder;
  final Set<String> selectedPaths;
  final bool isSelectionMode;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final int columns;
  final void Function(int auto, int max) onGridColumns;

  const FileManagerImageGrid({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onOpenFolder,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.columns,
    required this.onGridColumns,
  });

  @override
  State<FileManagerImageGrid> createState() => _FileManagerImageGridState();
}

class _FileManagerImageGridState extends State<FileManagerImageGrid> {
  final Set<String> _collapsedFolders = {};
  int? _reportedAutoColumns;
  int? _reportedMaxColumns;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).fileManagerNoImages),
      );
    }
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final groups = <String, List<FileManagerEntry>>{};
    for (final entry in widget.entries) {
      groups.putIfAbsent(p.dirname(entry.path), () => []).add(entry);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - _gridPadding * 2;
        _reportColumns(width);
        final columns = widget.columns.clamp(
          1,
          (width / _minTileExtent).floor().clamp(1, _maxColumns),
        );
        final tileExtent = (width - _spacing * (columns - 1)) / columns;
        return _buildGrid(
          context,
          l10n,
          locale,
          now,
          groups,
          columns,
          tileExtent,
        );
      },
    );
  }

  void _reportColumns(double width) {
    final auto = (width / _referenceTileExtent).round().clamp(1, _maxColumns);
    final max = (width / _minTileExtent).floor().clamp(1, _maxColumns);
    if (auto == _reportedAutoColumns && max == _reportedMaxColumns) return;
    _reportedAutoColumns = auto;
    _reportedMaxColumns = max;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onGridColumns(auto, max);
    });
  }

  Widget _buildGrid(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    DateTime now,
    Map<String, List<FileManagerEntry>> groups,
    int columns,
    double tileExtent,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final group in groups.entries) ...[
          SliverToBoxAdapter(
            child: _GroupHeader(
              folderPath: group.key,
              folder: fileManagerFolderLabel(group.key),
              count: group.value.length,
              collapsed: _collapsedFolders.contains(group.key),
              onToggle: () => setState(_toggleCollapsed(group.key)),
              onOpenFolder: widget.onOpenFolder,
            ),
          ),
          if (!_collapsedFolders.contains(group.key))
            for (final dateGroup in _byDate(
              group.value,
              now,
              locale,
              l10n,
            )) ...[
              SliverToBoxAdapter(child: _DateHeader(label: dateGroup.key)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: _spacing,
                    crossAxisSpacing: _spacing,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ImageTile(
                      entry: dateGroup.value[index],
                      tileExtent: tileExtent,
                      selected: widget.selectedPaths.contains(
                        dateGroup.value[index].path,
                      ),
                      selectionMode: widget.isSelectionMode,
                      onOpen: widget.onOpen,
                      onToggleSelection: widget.onToggleSelection,
                    ),
                    childCount: dateGroup.value.length,
                    addAutomaticKeepAlives: false,
                  ),
                ),
              ),
            ],
        ],
      ],
    );
  }

  /// Entries arrive newest first, so consecutive runs of the same date label
  /// are the groups — no extra sort, no map of the whole listing.
  List<MapEntry<String, List<FileManagerEntry>>> _byDate(
    List<FileManagerEntry> entries,
    DateTime now,
    String locale,
    AppLocalizations l10n,
  ) {
    final groups = <MapEntry<String, List<FileManagerEntry>>>[];
    for (final entry in entries) {
      final modified = entry.modified;
      final label = modified == null
          ? l10n.fileManagerUnknownDate
          : fileManagerDateGroup(modified, now, locale, l10n);
      if (groups.isNotEmpty && groups.last.key == label) {
        groups.last.value.add(entry);
      } else {
        groups.add(MapEntry(label, [entry]));
      }
    }
    return groups;
  }

  void Function() _toggleCollapsed(String folder) {
    return () {
      setState(() {
        if (!_collapsedFolders.remove(folder)) _collapsedFolders.add(folder);
      });
    };
  }
}

class _GroupHeader extends StatelessWidget {
  final String folderPath;
  final String folder;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<String> onOpenFolder;

  const _GroupHeader({
    required this.folderPath,
    required this.folder,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: collapsed
          ? l10n.fileManagerExpandGroup
          : l10n.fileManagerCollapseGroup,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  folder,
                  style: Theme.of(context).textTheme.titleSmall,
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.fileManagerItemCount(count),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: l10n.fileManagerOpenFolder,
                onPressed: () => onOpenFolder(folderPath),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              Icon(
                collapsed
                    ? Icons.expand_more_outlined
                    : Icons.expand_less_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: theme.dividerColor)),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final FileManagerEntry entry;
  final double tileExtent;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onToggleSelection;

  const _ImageTile({
    required this.entry,
    required this.tileExtent,
    required this.selected,
    required this.selectionMode,
    required this.onOpen,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => selectionMode ? onToggleSelection(entry) : onOpen(entry),
      onLongPress: () => onToggleSelection(entry),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x10888888)),
            // Decode at 2x tile width; height stays proportional so
            // BoxFit.cover crops correctly instead of distorting.
            Image.file(
              File(entry.path),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              cacheWidth:
                  (tileExtent * 2 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                if (wasSyncLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: child,
                );
              },
            ),
            if (selected)
              ColoredBox(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            if (selectionMode || selected)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? theme.colorScheme.primary : Colors.white70,
                  shadows: const [Shadow(blurRadius: 4)],
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  entry.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

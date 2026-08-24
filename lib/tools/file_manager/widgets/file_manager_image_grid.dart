import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_path_labels.dart';

const double _tileExtent = 160;

class FileManagerImageGrid extends StatefulWidget {
  final List<FileManagerEntry> entries;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<String> onOpenFolder;
  final Set<String> selectedPaths;
  final bool isSelectionMode;
  final ValueChanged<FileManagerEntry> onToggleSelection;

  const FileManagerImageGrid({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onOpenFolder,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.onToggleSelection,
  });

  @override
  State<FileManagerImageGrid> createState() => _FileManagerImageGridState();
}

class _FileManagerImageGridState extends State<FileManagerImageGrid> {
  final Set<String> _collapsedFolders = {};

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).fileManagerNoImages),
      );
    }
    final groups = <String, List<FileManagerEntry>>{};
    for (final entry in widget.entries) {
      groups.putIfAbsent(p.dirname(entry.path), () => []).add(entry);
    }

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
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _tileExtent,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ImageTile(
                  entry: group.value[index],
                  selected: widget.selectedPaths.contains(
                    group.value[index].path,
                  ),
                  selectionMode: widget.isSelectionMode,
                  onOpen: widget.onOpen,
                  onToggleSelection: widget.onToggleSelection,
                ),
                childCount: group.value.length,
                addAutomaticKeepAlives: false,
              ),
            ),
        ],
      ],
    );
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

class _ImageTile extends StatelessWidget {
  final FileManagerEntry entry;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onToggleSelection;

  const _ImageTile({
    required this.entry,
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
                  (_tileExtent * 2 * MediaQuery.devicePixelRatioOf(context))
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

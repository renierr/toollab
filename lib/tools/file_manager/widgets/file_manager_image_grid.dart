import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';

class FileManagerImageGrid extends StatefulWidget {
  final List<FileManagerEntry> entries;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<String> onOpenFolder;

  const FileManagerImageGrid({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onOpenFolder,
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
    final prefix = _commonPrefix(groups.keys);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final group in groups.entries) ...[
          SliverToBoxAdapter(
            child: _GroupHeader(
              folderPath: group.key,
              folder: _relativeFolder(group.key, prefix),
              count: group.value.length,
              collapsed: _collapsedFolders.contains(group.key),
              onToggle: () => setState(_toggleCollapsed(group.key)),
              onOpenFolder: widget.onOpenFolder,
            ),
          ),
          if (!_collapsedFolders.contains(group.key))
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ImageTile(
                  entry: group.value[index],
                  onOpen: widget.onOpen,
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

  String _commonPrefix(Iterable<String> directories) {
    if (directories.isEmpty) return '';
    var segments = directories.first
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    for (final directory in directories.skip(1)) {
      final parts = directory
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();
      var shared = 0;
      while (shared < segments.length &&
          shared < parts.length &&
          segments[shared].toLowerCase() == parts[shared].toLowerCase()) {
        shared++;
      }
      segments = segments.sublist(0, shared);
      if (segments.isEmpty) break;
    }
    return segments.join('/');
  }

  /// Strips the prefix every group shares so headers show e.g.
  /// "DCIM/Camera" instead of the full storage path.
  String _relativeFolder(String directory, String prefix) {
    var normalized = directory.replaceAll('\\', '/');
    if (prefix.isNotEmpty &&
        normalized.toLowerCase().startsWith(prefix.toLowerCase())) {
      normalized = normalized.substring(prefix.length);
    }
    final relative = normalized
        .split('/')
        .where((part) => part.isNotEmpty)
        .join('/');
    return relative.isEmpty ? p.basename(directory) : relative;
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
  final ValueChanged<FileManagerEntry> onOpen;

  const _ImageTile({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onOpen(entry),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(entry.path),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: 320,
              cacheHeight: 320,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
              gaplessPlayback: true,
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                  maxLines: 1,
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

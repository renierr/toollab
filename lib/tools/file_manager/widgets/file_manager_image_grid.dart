import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_grouped_image_grid.dart';

class FileManagerImageGrid extends StatefulWidget {
  final List<FileManagerEntry> entries;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<String> onOpenFolder;
  final Set<String> selectedPaths;
  final bool isSelectionMode;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final double tileSize;
  final bool crop;
  final ValueChanged<double> onGridWidth;

  const FileManagerImageGrid({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onOpenFolder,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.tileSize,
    required this.crop,
    required this.onGridWidth,
  });

  @override
  State<FileManagerImageGrid> createState() => _FileManagerImageGridState();
}

class _FileManagerImageGridState extends State<FileManagerImageGrid> {
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
    return FileManagerGroupedImageGrid(
      groups: groups,
      tileSize: widget.tileSize,
      selectedPaths: widget.selectedPaths,
      isSelectionMode: widget.isSelectionMode,
      onOpen: widget.onOpen,
      onOpenFolder: widget.onOpenFolder,
      onToggleSelection: widget.onToggleSelection,
      crop: widget.crop,
      onGridWidth: widget.onGridWidth,
    );
  }
}

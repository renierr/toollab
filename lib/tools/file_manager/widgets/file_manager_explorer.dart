import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerExplorer extends StatelessWidget {
  final FileManagerState state;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final VoidCallback onGoUp;
  final VoidCallback onToggleFavorite;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelection;
  const FileManagerExplorer({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.onGoUp,
    required this.onToggleFavorite,
    required this.onToggleSelection,
    required this.onClearSelection,
    required this.onDeleteSelection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.commonBack,
                onPressed: state.canGoUp ? onGoUp : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(
                child: Text(
                  state.path.isEmpty ? '/' : state.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!state.isRemote)
                IconButton(
                  tooltip: l10n.fileManagerFavorite,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    state.favoritePaths.contains(state.path)
                        ? Icons.star
                        : Icons.star_outline,
                  ),
                ),
            ],
          ),
        ),
        if (state.hasSelection)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: onClearSelection,
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    l10n.fileManagerSelected(state.selectedPaths.length),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonCopy,
                  onPressed: () => onCopy(
                    state.entries.firstWhere(
                      (entry) => state.selectedPaths.contains(entry.path),
                    ),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: l10n.fileManagerCut,
                  onPressed: () => onCut(
                    state.entries.firstWhere(
                      (entry) => state.selectedPaths.contains(entry.path),
                    ),
                  ),
                  icon: const Icon(Icons.drive_file_move_outline),
                ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  onPressed: onDeleteSelection,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        if (state.isOperating)
          LinearProgressIndicator(value: state.operationProgress),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: state.entries.isEmpty
              ? Center(child: Text(l10n.fileManagerEmptyFolder))
              : ListView.builder(
                  itemCount: state.entries.length,
                  itemBuilder: (context, index) => _EntryTile(
                    entry: state.entries[index],
                    onOpen: onOpen,
                    onRename: onRename,
                    onDelete: onDelete,
                    onCopy: onCopy,
                    onCut: onCut,
                    showClipboardActions: !state.isRemote,
                    selected: state.selectedPaths.contains(
                      state.entries[index].path,
                    ),
                    onToggleSelection: onToggleSelection,
                  ),
                ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final FileManagerEntry entry;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final bool showClipboardActions;
  final bool selected;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  const _EntryTile({
    required this.entry,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.showClipboardActions,
    required this.selected,
    required this.onToggleSelection,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(_iconFor(entry), color: _colorFor(context, entry)),
    selected: selected,
    title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: entry.isDirectory
        ? null
        : Text(entry.size == null ? '' : FormatHelper.fileSize(entry.size!)),
    trailing: PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'rename') {
          onRename(entry);
        } else if (value == 'copy') {
          onCopy(entry);
        } else if (value == 'cut') {
          onCut(entry);
        } else {
          onDelete(entry);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Text(AppLocalizations.of(context).commonRename),
        ),
        if (showClipboardActions)
          PopupMenuItem(
            value: 'copy',
            child: Text(AppLocalizations.of(context).commonCopy),
          ),
        if (showClipboardActions)
          PopupMenuItem(
            value: 'cut',
            child: Text(AppLocalizations.of(context).fileManagerCut),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Text(AppLocalizations.of(context).commonDelete),
        ),
      ],
    ),
    onTap: () => onOpen(entry),
    onLongPress: () => onToggleSelection(entry),
  );

  IconData _iconFor(FileManagerEntry entry) {
    if (entry.isDirectory) return Icons.folder_outlined;
    final extension = entry.name.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'md' || 'markdown' || 'txt' => Icons.article_outlined,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' ||
      'svg' => Icons.image_outlined,
      'mp3' || 'wav' || 'ogg' || 'flac' || 'm4a' => Icons.audio_file_outlined,
      'mp4' || 'webm' || 'mov' || 'avi' => Icons.video_file_outlined,
      'zip' || '7z' || 'rar' || 'tar' || 'gz' => Icons.folder_zip_outlined,
      'dart' ||
      'kt' ||
      'java' ||
      'js' ||
      'ts' ||
      'py' ||
      'json' ||
      'yaml' => Icons.code_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  Color _colorFor(BuildContext context, FileManagerEntry entry) {
    if (entry.isDirectory) return Theme.of(context).colorScheme.primary;
    final extension = entry.name.split('.').last.toLowerCase();
    if (extension == 'pdf') return Theme.of(context).colorScheme.error;
    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'svg',
    ].contains(extension)) {
      return Theme.of(context).colorScheme.tertiary;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

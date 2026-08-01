import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerExplorer extends StatelessWidget {
  final FileManagerState state;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onOpenWithSystem;
  final ValueChanged<FileManagerEntry> onDetails;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final VoidCallback onGoUp;
  final VoidCallback onToggleFavorite;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelection;
  const FileManagerExplorer({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onOpenWithSystem,
    required this.onDetails,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.onGoUp,
    required this.onToggleFavorite,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
    required this.onSelectAll,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isRemote)
                      Row(
                        children: [
                          Icon(
                            state.connection?.protocol ==
                                    FileManagerProtocol.ftp
                                ? Icons.cloud_outlined
                                : Icons.folder_shared_outlined,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              state.connection?.label ?? '',
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    Text(
                      state.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
              IconButton(
                tooltip: l10n.fileManagerSelect,
                onPressed: onEnterSelectionMode,
                icon: const Icon(Icons.checklist_outlined),
              ),
            ],
          ),
        ),
        if (state.isSelectionMode)
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
                  tooltip: l10n.fileManagerSelectAll,
                  onPressed: onSelectAll,
                  icon: const Icon(Icons.select_all),
                ),
                IconButton(
                  tooltip: l10n.commonCopy,
                  onPressed: state.hasSelection
                      ? () => onCopy(
                          state.entries.firstWhere(
                            (entry) => state.selectedPaths.contains(entry.path),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: l10n.fileManagerCut,
                  onPressed: state.hasSelection
                      ? () => onCut(
                          state.entries.firstWhere(
                            (entry) => state.selectedPaths.contains(entry.path),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.drive_file_move_outline),
                ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  onPressed: state.hasSelection ? onDeleteSelection : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        if (state.isOperating) _OperationProgress(state: state),
        if (state.canPaste) _ClipboardHint(state: state),
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
                    onOpenWithSystem: onOpenWithSystem,
                    onDetails: onDetails,
                    onRename: onRename,
                    onDelete: onDelete,
                    onCopy: onCopy,
                    onCut: onCut,
                    showClipboardActions:
                        state.connection?.protocol != FileManagerProtocol.ftp,
                    selectionMode: state.isSelectionMode,
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

class _OperationProgress extends StatelessWidget {
  final FileManagerState state;
  const _OperationProgress({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = state.operationProgress ?? 0;
    final label = switch (state.operation) {
      FileManagerOperation.copy => l10n.fileManagerCopying,
      FileManagerOperation.move => l10n.fileManagerMoving,
      FileManagerOperation.delete => l10n.fileManagerDeleting,
      null => l10n.commonLoading,
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text('${(progress * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            l10n.fileManagerOperationProgress(
              state.operationCompleted,
              state.operationTotal,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            l10n.fileManagerOperationBackground,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ClipboardHint extends StatelessWidget {
  final FileManagerState state;
  const _ClipboardHint({required this.state});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = state.clipboardIsCut
        ? l10n.fileManagerMoveBuffer(state.clipboardItemCount)
        : l10n.fileManagerCopyBuffer(state.clipboardItemCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            state.clipboardIsCut
                ? Icons.drive_file_move_outline
                : Icons.copy_outlined,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final FileManagerEntry entry;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onOpenWithSystem;
  final ValueChanged<FileManagerEntry> onDetails;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final bool showClipboardActions;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  const _EntryTile({
    required this.entry,
    required this.onOpen,
    required this.onOpenWithSystem,
    required this.onDetails,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.showClipboardActions,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(_iconFor(entry), color: _colorFor(context, entry)),
    selected: selected,
    title: Text(
      entry.name,
      maxLines: MediaQuery.sizeOf(context).width < 720 ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      _metadata(entry),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
      ),
    ),
    trailing: selectionMode
        ? Checkbox(value: selected, onChanged: (_) => onToggleSelection(entry))
        : PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                onRename(entry);
              } else if (value == 'details') {
                onDetails(entry);
              } else if (value == 'system') {
                onOpenWithSystem(entry);
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
                value: 'details',
                child: Text(AppLocalizations.of(context).fileManagerDetails),
              ),
              PopupMenuItem(
                value: 'system',
                child: Text(
                  AppLocalizations.of(context).fileManagerOpenWithSystem,
                ),
              ),
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
    onTap: () => selectionMode ? onToggleSelection(entry) : onOpen(entry),
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

  String _metadata(FileManagerEntry entry) {
    final parts = <String>[];
    if (entry.modified != null) {
      parts.add(FormatHelper.dateTime(entry.modified!));
    }
    if (!entry.isDirectory && entry.size != null) {
      parts.add(FormatHelper.fileSize(entry.size!));
    }
    return parts.join('  -  ');
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

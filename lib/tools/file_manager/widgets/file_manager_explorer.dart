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
  const _EntryTile({
    required this.entry,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.showClipboardActions,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      entry.isDirectory
          ? Icons.folder_outlined
          : Icons.insert_drive_file_outlined,
    ),
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
  );
}

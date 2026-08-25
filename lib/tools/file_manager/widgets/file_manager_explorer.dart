import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_apps_view.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_breadcrumbs.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_tile.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_file_drop_zone.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_image_grid.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_system_view.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

class FileManagerExplorer extends StatelessWidget {
  final FileManagerState state;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onOpenWithSystem;
  final ValueChanged<FileManagerEntry> onShare;
  final ValueChanged<FileManagerEntry> onDetails;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final VoidCallback onGoUp;
  final ValueChanged<String> onOpenPath;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleSortField;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelection;
  final VoidCallback onMoveSelection;
  final VoidCallback onCreateZip;
  final ValueChanged<FileManagerEntry> onExtract;
  final AsyncCallback onRefresh;
  final Future<void> Function(List<String> paths, bool chooseAction)
  onDropFiles;
  final ScrollController scrollController;
  final VoidCallback onCloseCategory;
  const FileManagerExplorer({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onOpenWithSystem,
    required this.onShare,
    required this.onDetails,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.onGoUp,
    required this.onOpenPath,
    required this.onToggleFavorite,
    required this.onToggleSortField,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
    required this.onSelectAll,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onDeleteSelection,
    required this.onMoveSelection,
    required this.onCreateZip,
    required this.onExtract,
    required this.onRefresh,
    required this.onDropFiles,
    required this.scrollController,
    required this.onCloseCategory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.isBrowsingCategory) {
      return _CategoryView(
        state: state,
        onClose: onCloseCategory,
        onRefresh: onRefresh,
        onOpenImage: onOpen,
        onOpenSystemPath: onOpenPath,
        onToggleSelection: onToggleSelection,
        onEnterSelectionMode: onEnterSelectionMode,
        onToggleSelectAll: onToggleSelectAll,
        onClearSelection: onClearSelection,
        onDeleteSelection: onDeleteSelection,
        onMoveSelection: onMoveSelection,
      );
    }
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
                    FileManagerBreadcrumbs(
                      state: state,
                      onOpenPath: onOpenPath,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    '${l10n.fileManagerSortBy}: '
                    '${state.activeSortField == FileManagerSortField.modified ? l10n.fileManagerSortDate : l10n.fileManagerSortName}',
                onPressed: onToggleSortField,
                icon: Icon(
                  state.activeSortField == FileManagerSortField.modified
                      ? Icons.schedule_outlined
                      : Icons.sort_by_alpha,
                ),
              ),
              if (!state.isRemote && !state.isReadOnly)
                IconButton(
                  tooltip: l10n.fileManagerFavorite,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    state.favoritePaths.contains(state.path)
                        ? Icons.star
                        : Icons.star_outline,
                  ),
                ),
              if (state.hasSelection && !state.isRemote && !state.isReadOnly)
                IconButton(
                  tooltip: l10n.fileManagerCompressZip,
                  onPressed: onCreateZip,
                  icon: const Icon(Icons.folder_zip_outlined),
                ),
              IconButton(
                tooltip: l10n.fileManagerSelect,
                onPressed: state.isOperating ? null : onEnterSelectionMode,
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
                  onPressed: state.isOperating ? null : onClearSelection,
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    l10n.fileManagerSelected(state.selectedPaths.length),
                  ),
                ),
                if (!state.isReadOnly)
                  IconButton(
                    tooltip: state.selectedPaths.length == state.entries.length
                        ? l10n.commonClear
                        : l10n.fileManagerSelectAll,
                    onPressed:
                        state.selectedPaths.length == state.entries.length
                        ? state.isOperating
                              ? null
                              : onClearSelection
                        : state.isOperating
                        ? null
                        : onSelectAll,
                    icon: Icon(
                      state.selectedPaths.length == state.entries.length
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                  ),
                IconButton(
                  tooltip: l10n.commonCopy,
                  onPressed: state.hasSelection && !state.isOperating
                      ? () => onCopy(
                          state.entries.firstWhere(
                            (entry) => state.selectedPaths.contains(entry.path),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                ),
                if (!state.isReadOnly)
                  IconButton(
                    tooltip: l10n.fileManagerCut,
                    onPressed: state.hasSelection && !state.isOperating
                        ? () => onCut(
                            state.entries.firstWhere(
                              (entry) =>
                                  state.selectedPaths.contains(entry.path),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.drive_file_move_outline),
                  ),
                if (!state.isReadOnly)
                  IconButton(
                    tooltip: l10n.commonDelete,
                    onPressed: state.hasSelection && !state.isOperating
                        ? onDeleteSelection
                        : null,
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
          child: FileManagerFileDropZone(
            enabled: !state.isOperating && !state.isRemote && !state.isReadOnly,
            onDrop: onDropFiles,
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: LayoutBuilder(
                builder: (context, constraints) => state.entries.isEmpty
                    ? ListView(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: Center(
                              child: Text(l10n.fileManagerEmptyFolder),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemExtent:
                            constraints.maxWidth <
                                ResponsiveLayout.mobileBreakpoint
                            ? 88
                            : 72,
                        itemCount: state.entries.length,
                        itemBuilder: (context, index) => FileManagerEntryTile(
                          entry: state.entries[index],
                          onOpen: onOpen,
                          onOpenWithSystem: onOpenWithSystem,
                          onShare: onShare,
                          onDetails: onDetails,
                          onRename: onRename,
                          onDelete: onDelete,
                          onCopy: onCopy,
                          onCut: onCut,
                          onExtract: onExtract,
                          showClipboardActions:
                              state.connection?.protocol !=
                              FileManagerProtocol.ftp,
                          selectionMode: state.isSelectionMode,
                          selected: state.selectedPaths.contains(
                            state.entries[index].path,
                          ),
                          onToggleSelection: onToggleSelection,
                          isInClipboard: state.clipboardPaths.contains(
                            state.entries[index].path,
                          ),
                          clipboardIsCut: state.clipboardIsCut,
                          readOnly: state.isReadOnly,
                          showImagePreviews: !state.isRemote,
                          metadata: state.metadataFor(state.entries[index]),
                          childCount: state.childCountFor(state.entries[index]),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryView extends StatelessWidget {
  final FileManagerState state;
  final VoidCallback onClose;
  final AsyncCallback onRefresh;
  final ValueChanged<FileManagerEntry> onOpenImage;
  final ValueChanged<String> onOpenSystemPath;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelection;
  final VoidCallback onMoveSelection;

  const _CategoryView({
    required this.state,
    required this.onClose,
    required this.onRefresh,
    required this.onOpenImage,
    required this.onOpenSystemPath,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onDeleteSelection,
    required this.onMoveSelection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selecting = state.isSelectionMode || state.hasSelection;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              IconButton(
                tooltip: selecting ? l10n.commonCancel : l10n.commonBack,
                onPressed: state.isLoading
                    ? null
                    : selecting
                    ? onClearSelection
                    : onClose,
                icon: Icon(selecting ? Icons.close : Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  selecting
                      ? l10n.fileManagerSelected(state.selectedPaths.length)
                      : state.categoryTitle(l10n),
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.category == FileManagerCategory.images &&
                  !selecting) ...[
                IconButton(
                  tooltip: l10n.fileManagerZoomOut,
                  onPressed: state.canShrinkImageTiles
                      ? () => state.stepImageTileSize(false)
                      : null,
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  tooltip: l10n.fileManagerZoomIn,
                  onPressed: state.canEnlargeImageTiles
                      ? () => state.stepImageTileSize(true)
                      : null,
                  icon: const Icon(Icons.zoom_in),
                ),
              ],
              if (state.category == FileManagerCategory.images &&
                  !state.isRemote) ...[
                if (!selecting)
                  IconButton(
                    tooltip: l10n.fileManagerSelect,
                    onPressed: state.isLoading || state.entries.isEmpty
                        ? null
                        : onEnterSelectionMode,
                    icon: const Icon(Icons.checklist_outlined),
                  ),
                IconButton(
                  tooltip: state.isAllSelected
                      ? l10n.fileManagerDeselectAll
                      : l10n.fileManagerSelectAll,
                  onPressed: state.isLoading || state.entries.isEmpty
                      ? null
                      : onToggleSelectAll,
                  icon: Icon(
                    state.isAllSelected ? Icons.deselect : Icons.select_all,
                  ),
                ),
                if (selecting) ...[
                  IconButton(
                    tooltip: l10n.fileManagerMove,
                    onPressed: state.isLoading || !state.hasSelection
                        ? null
                        : onMoveSelection,
                    icon: const Icon(Icons.drive_file_move_outline),
                  ),
                  IconButton(
                    tooltip: l10n.commonDelete,
                    onPressed: state.isLoading || !state.hasSelection
                        ? null
                        : onDeleteSelection,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
              IconButton(
                tooltip: l10n.fileManagerRefresh,
                onPressed: state.isLoading ? null : () => onRefresh(),
                icon: const Icon(Icons.refresh),
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
          child: state.isLoading && _bodyEmpty
              ? const Center(child: CircularProgressIndicator())
              : switch (state.category) {
                  FileManagerCategory.images => RefreshIndicator(
                    onRefresh: onRefresh,
                    child: FileManagerImageGrid(
                      entries: state.entries,
                      onOpen: onOpenImage,
                      onOpenFolder: (path) => state.openLocal(path),
                      selectedPaths: state.selectedPaths,
                      isSelectionMode: state.isSelectionMode,
                      onToggleSelection: onToggleSelection,
                      tileSize: state.imageTileSize,
                      crop: state.cropImagePreviews,
                      onGridWidth: state.reportImageGridWidth,
                    ),
                  ),
                  FileManagerCategory.apps => FileManagerAppsView(
                    apps: state.installedApps,
                    storageInfo: state.storageInfo,
                  ),
                  FileManagerCategory.system => FileManagerSystemView(
                    entries: state.entries,
                    onOpen: (entry) => onOpenSystemPath(entry.path),
                  ),
                  FileManagerCategory.none => const SizedBox.shrink(),
                },
        ),
      ],
    );
  }

  bool get _bodyEmpty =>
      state.category != FileManagerCategory.apps || state.installedApps.isEmpty;
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
      FileManagerOperation.compress => l10n.fileManagerCompressing,
      FileManagerOperation.extract => l10n.fileManagerExtracting,
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
            state.operationTotal == 0
                ? l10n.commonLoading
                : l10n.fileManagerOperationProgress(
                    state.operationCompleted,
                    state.operationTotal,
                  ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/native_media_player.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/archives/archive_handler.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_connection_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_archive_conflict_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_delete_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_details_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_name_list.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_drop_action_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_explorer.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_locations.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_name_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_back_button.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage>
    with DisposeCleanup, WidgetsBindingObserver {
  late final TempFileScope _tempScope;
  late final ScrollController _scrollController;
  late final FileManagerState _state;
  final Map<String, double> _scrollOffsets = {};
  bool _awaitingStorageAccess = false;
  String? _lastPath;
  int? _lastListing;
  double? _pendingScrollOffset;
  bool _restoreScheduled = false;

  @override
  void initState() {
    super.initState();
    _tempScope = TempFileManager.createScope();
    _scrollController = ScrollController()..addListener(_trackScrollOffset);
    WidgetsBinding.instance.addObserver(this);
    _state = context.read<FileManagerState>();
    onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _tempScope.cleanTracked();
      _scrollController.removeListener(_trackScrollOffset);
      _scrollController.dispose();
      _state.releaseOnExit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) context.read<FileManagerState>().initialize();
      });
    });
  }

  Future<void> _openEntry(FileManagerEntry entry) async {
    final state = context.read<FileManagerState>();
    if (entry.isBrokenLink) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).fileManagerBrokenLink),
        ),
      );
      return;
    }
    if (entry.isDirectory || state.canBrowseArchive(entry)) {
      _saveScrollOffset(state.path);
      await state.openEntry(entry);
      return;
    }
    final path = await state.prepareForOpen(
      entry,
      () => _tempScope.createFile('file_manager_${entry.name}'),
    );
    if (!mounted || path == null) return;
    try {
      final mimeType = MimeTypeHelper.getMimeType(entry.name);
      final origin = state.originFor(entry);
      final category = state.openCategoryForMime(mimeType);
      final toolId = category == null ? null : state.openToolId(category);
      if (toolId == NativeMediaPlayer.preferenceId) {
        await NativeMediaPlayer.open(path: path, mimeType: mimeType);
        return;
      }
      final tool = toolId == null
          ? null
          : ToolRegistry.all
                .where((candidate) => candidate.id == toolId)
                .firstOrNull;
      if (tool != null) {
        context.push(
          tool.route,
          extra: SharedData.single(
            SharedFile(
              path: path,
              name: entry.name,
              mimeType: mimeType,
              origin: origin,
            ),
          ),
        );
        return;
      }
      await FileSaveHelper.showOpenChooser(
        context: context,
        path: path,
        mimeType: mimeType,
        origin: origin,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _saveScrollOffset(String path) {
    if (!_scrollController.hasClients) return;
    if (_scrollOffsets.length > 30) {
      _scrollOffsets.remove(_scrollOffsets.keys.first);
    }
    _scrollOffsets[path] = _scrollController.offset;
  }

  /// Records the position continuously, so a reload of the same folder (delete,
  /// rename, paste, manual refresh) can restore it too. Skipped while a listing
  /// is being replaced or a restore is pending, since both drive the offset to
  /// values the user never chose.
  void _trackScrollOffset() {
    final path = _lastPath;
    if (path == null || _pendingScrollOffset != null || _state.isLoading) {
      return;
    }
    _saveScrollOffset(path);
  }

  /// The listing streams in batches and gets re-sorted once metadata arrives, so a
  /// single post-frame jump would land on a list that is still too short. Retry
  /// until the extent can honour the offset or the folder is fully loaded.
  void _scheduleScrollRestore(FileManagerState state) {
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      final offset = _pendingScrollOffset;
      if (offset == null || !mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset != offset.clamp(0.0, maxExtent)) {
        _scrollController.jumpTo(offset.clamp(0.0, maxExtent));
      }
      if (maxExtent >= offset ||
          (!state.isLoading && !state.isScanningMetadata)) {
        _pendingScrollOffset = null;
      }
    });
  }

  Future<void> _openLocal(String path) async {
    final state = context.read<FileManagerState>();
    _saveScrollOffset(state.path);
    await state.openLocal(path);
  }

  Future<void> _openPath(String path) async {
    final state = context.read<FileManagerState>();
    _saveScrollOffset(state.path);
    await state.openPath(path);
  }

  Future<void> _goUp() async {
    final state = context.read<FileManagerState>();
    _saveScrollOffset(state.path);
    await state.goUp();
  }

  Future<void> _openWithSystem(FileManagerEntry entry) async {
    final path = await context.read<FileManagerState>().prepareForOpen(
      entry,
      () => _tempScope.createFile('file_manager_${entry.name}'),
    );
    if (path != null) {
      await FileSaveHelper.openFile(
        path,
        MimeTypeHelper.getMimeType(entry.name),
      );
    }
  }

  Future<void> _openWithChooser(FileManagerEntry entry) async {
    final path = await context.read<FileManagerState>().prepareForOpen(
      entry,
      () => _tempScope.createFile('file_manager_${entry.name}'),
    );
    if (!mounted || path == null) return;
    await FileSaveHelper.showOpenChooser(
      context: context,
      path: path,
      mimeType: MimeTypeHelper.getMimeType(entry.name),
    );
  }

  Future<void> _showDetails(FileManagerEntry entry) async {
    final folderItemCount = await context
        .read<FileManagerState>()
        .folderItemCount(entry);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => FileManagerDetailsDialog(
        entry: entry,
        folderItemCount: folderItemCount,
        onOpen: () {
          Navigator.pop(context);
          _openWithChooser(entry);
        },
        onShare: () {
          Navigator.pop(context);
          _shareWithSystem(entry);
        },
      ),
    );
  }

  Future<void> _shareWithSystem(FileManagerEntry entry) async {
    final path = await context.read<FileManagerState>().prepareForOpen(
      entry,
      () => _tempScope.createFile('file_manager_share_${entry.name}'),
    );
    if (path != null) {
      await FileSaveHelper.shareFile(
        path,
        MimeTypeHelper.getMimeType(entry.name),
      );
    }
  }

  Future<void> _createFolder() async {
    final name = await _showNameDialog(
      AppLocalizations.of(context).fileManagerNewFolder,
    );
    if (name != null && mounted) {
      await context.read<FileManagerState>().createFolder(name);
    }
  }

  Future<void> _createZip() async {
    final name = await _showNameDialog(
      AppLocalizations.of(context).fileManagerCompressZip,
      initialValue: 'archive.zip',
    );
    if (name != null && mounted) {
      await context.read<FileManagerState>().createZip(name);
    }
  }

  Future<void> _extractArchive(FileManagerEntry entry) async {
    final state = context.read<FileManagerState>();
    final conflicts = await state.archiveConflicts(entry);
    if (!mounted) return;
    final conflictResult = conflicts.isEmpty
        ? (true, ArchiveConflictResolution.keepBoth)
        : await showDialog<(bool, ArchiveConflictResolution)>(
            context: context,
            builder: (_) =>
                FileManagerArchiveConflictDialog(conflictPaths: conflicts),
          );
    if (conflictResult != null && mounted) {
      var firstConflict = true;
      var applyToAll = conflictResult.$1;
      var resolution = conflictResult.$2;
      await state.extractArchive(entry, (path) async {
        if (applyToAll || firstConflict) {
          firstConflict = false;
          return resolution;
        }
        if (!mounted) return ArchiveConflictResolution.skip;
        final result = await showDialog<(bool, ArchiveConflictResolution)>(
          context: context,
          builder: (_) => FileManagerArchiveConflictDialog(
            conflictPaths: [path],
            initialApplyToAll: applyToAll,
          ),
        );
        if (result == null) return ArchiveConflictResolution.skip;
        applyToAll = result.$1;
        resolution = result.$2;
        return resolution;
      });
    }
  }

  Future<void> _rename(FileManagerEntry entry) async {
    final name = await _showNameDialog(
      AppLocalizations.of(context).commonRename,
      initialValue: entry.name,
    );
    if (name != null && mounted) {
      await context.read<FileManagerState>().rename(entry, name);
    }
  }

  Future<void> _delete(FileManagerEntry entry) async {
    final state = context.read<FileManagerState>();
    if (state.selectedPaths.contains(entry.path)) {
      await _confirmDelete();
      return;
    }
    // The row menu deletes through the same bulk path, but must not leave the
    // list in selection mode when the confirmation is dismissed.
    state.selectForAction(entry);
    if (!await _confirmDelete()) state.clearSelection();
  }

  Future<bool> _confirmDelete() async {
    final state = context.read<FileManagerState>();
    final selected = state.entries
        .where((entry) => state.selectedPaths.contains(entry.path))
        .toList();
    if (selected.isEmpty) return false;
    // Only the folders the dialog actually lists get counted.
    final folderFileCounts = <String, int>{};
    for (final entry
        in selected
            .take(FileManagerEntryNameList.limit)
            .where((entry) => entry.isDirectory)) {
      final count = await state.folderFileCount(entry);
      if (count != null) folderFileCounts[entry.path] = count;
    }
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => FileManagerDeleteDialog(
        entries: selected,
        folderFileCounts: folderFileCounts,
      ),
    );
    if (confirmed != true || !mounted) return false;
    await state.deleteSelected();
    return true;
  }

  Future<void> _addConnection() async {
    final result = await showDialog<(FileManagerConnection, String)>(
      context: context,
      builder: (_) => FileManagerConnectionDialog(
        onDiscoverSmbShares: context.read<FileManagerState>().discoverSmbShares,
      ),
    );
    if (result != null && mounted) {
      await context.read<FileManagerState>().saveConnection(
        result.$1,
        result.$2,
      );
    }
  }

  Future<void> _requestStorageAccess() async {
    _awaitingStorageAccess = true;
    await FileManagerStorageAccess.requestAllFilesAccess();
  }

  Future<void> _paste() async {
    final state = context.read<FileManagerState>();
    final conflicts = await state.localPasteConflicts();
    if (!mounted || conflicts.isEmpty) {
      await state.paste();
      return;
    }
    final resolution = await showDialog<FileManagerConflictResolution>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(AppLocalizations.of(context).fileManagerFileExistsTitle),
        content: Text(
          AppLocalizations.of(
            context,
          ).fileManagerFileExistsMessage(conflicts.join(', ')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, FileManagerConflictResolution.keepBoth),
            child: Text(AppLocalizations.of(context).fileManagerKeepBoth),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, FileManagerConflictResolution.overwrite),
            child: Text(AppLocalizations.of(context).fileManagerOverwrite),
          ),
        ],
      ),
    );
    if (resolution != null && mounted) {
      await state.paste(resolution: resolution);
    }
  }

  Future<void> _dropFiles(List<String> paths, bool chooseAction) async {
    var move = false;
    if (chooseAction) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => const FileManagerDropActionDialog(),
      );
      if (result == null || !mounted) return;
      move = result;
    }
    await context.read<FileManagerState>().importDroppedFiles(
      paths,
      move: move,
    );
  }

  Future<void> _removeConnection(FileManagerConnection profile) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.fileManagerRemoveConnectionTitle),
        content: Text(l10n.fileManagerRemoveConnectionMessage(profile.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<FileManagerState>().removeConnection(profile);
    }
  }

  Future<void> _showSettings() async {
    await context.push('${FileManagerTool.config.route}/settings');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_awaitingStorageAccess) {
      _awaitingStorageAccess = false;
      context.read<FileManagerState>().initialize();
      return;
    }
    // Files may have changed elsewhere while the app was backgrounded.
    if (!_state.isLoading) _state.refresh();
  }

  Future<String?> _showNameDialog(
    String title, {
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          FileManagerNameDialog(title: title, initialValue: initialValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<FileManagerState>();
    if (_lastPath != state.path || _lastListing != state.listingGeneration) {
      _lastPath = state.path;
      _lastListing = state.listingGeneration;
      _pendingScrollOffset = _scrollOffsets[state.path];
    }
    if (_pendingScrollOffset != null) _scheduleScrollRestore(state);
    return PopScope(
      canPop: !state.canNavigateBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.canNavigateBack) _goUp();
      },
      child: ToolLayout(
        title: FileManagerTool.config.localizedName(l10n),
        leading: const ToolBackButton(exitTool: true),
        actions: [
          IconButton(
            tooltip: l10n.commonSettings,
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_outlined),
          ),
          if (state.requiresStorageAccess)
            IconButton(
              tooltip: l10n.fileManagerAllFilesAccess,
              onPressed: _requestStorageAccess,
              icon: const Icon(Icons.folder_open_outlined),
            ),
          IconButton(
            tooltip: l10n.fileManagerRefresh,
            onPressed: state.isLoading ? null : state.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.fileManagerNewFolder,
            onPressed: state.isLoading || state.isReadOnly
                ? null
                : _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          if (state.canPaste)
            IconButton(
              tooltip: l10n.fileManagerPaste,
              onPressed:
                  state.isLoading ||
                      state.isReadOnly ||
                      state.isRemote &&
                          state.connection?.protocol == FileManagerProtocol.ftp
                  ? null
                  : _paste,
              icon: Icon(
                state.clipboardIsCut
                    ? Icons.drive_file_move_outline
                    : Icons.content_paste_outlined,
              ),
            ),
          if (state.canPaste)
            IconButton(
              tooltip: l10n.fileManagerClearClipboard,
              onPressed: state.clearClipboard,
              icon: const Icon(Icons.clear_all_outlined),
            ),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final locations = FileManagerLocations(
              state: state,
              onOpenLocal: _openLocal,
              onOpenPath: _openPath,
              onOpenConnection: state.openConnection,
              onAddConnection: _addConnection,
              onRemoveConnection: _removeConnection,
              onRequestStorageAccess: _requestStorageAccess,
            );
            final explorer = NotificationListener<UserScrollNotification>(
              onNotification: (_) {
                _pendingScrollOffset = null;
                return false;
              },
              child: FileManagerExplorer(
                state: state,
                onOpen: _openEntry,
                onOpenWithSystem: _openWithSystem,
                onShare: _shareWithSystem,
                onDetails: _showDetails,
                onRename: _rename,
                onDelete: _delete,
                onCopy: state.copy,
                onCut: state.cut,
                onGoUp: _goUp,
                onOpenPath: _openPath,
                onToggleFavorite: state.toggleFavorite,
                onToggleSortField: state.toggleSortField,
                onToggleSelection: state.toggleSelection,
                onEnterSelectionMode: state.enterSelectionMode,
                onSelectAll: state.selectAll,
                onClearSelection: state.clearSelection,
                onDeleteSelection: _confirmDelete,
                onCreateZip: _createZip,
                onExtract: _extractArchive,
                onRefresh: state.refresh,
                onDropFiles: _dropFiles,
                scrollController: _scrollController,
              ),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  locations,
                  Expanded(child: explorer),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 280, child: locations),
                const VerticalDivider(width: 1),
                Expanded(child: explorer),
              ],
            );
          },
        ),
      ),
    );
  }
}

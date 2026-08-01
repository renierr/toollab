import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/config.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_connection_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_details_dialog.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_explorer.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_locations.dart';
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
  bool _awaitingStorageAccess = false;

  @override
  void initState() {
    super.initState();
    _tempScope = TempFileManager.createScope();
    WidgetsBinding.instance.addObserver(this);
    onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _tempScope.cleanTracked();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) context.read<FileManagerState>().initialize();
      });
    });
  }

  Future<void> _openEntry(FileManagerEntry entry) async {
    final state = context.read<FileManagerState>();
    if (entry.isDirectory) {
      await state.openEntry(entry);
      return;
    }
    final path = await state.prepareForOpen(
      entry,
      await _tempScope.createFile('file_manager_${entry.name}'),
    );
    if (!mounted || path == null) return;
    try {
      final mimeType = MimeTypeHelper.getMimeType(entry.name);
      final category = state.openCategoryForMime(mimeType);
      final toolId = category == null ? null : state.openToolId(category);
      final tool = toolId == null
          ? null
          : ToolRegistry.all
                .where((candidate) => candidate.id == toolId)
                .firstOrNull;
      if (tool != null) {
        context.push(
          tool.route,
          extra: SharedData.single(
            SharedFile(path: path, name: entry.name, mimeType: mimeType),
          ),
        );
        return;
      }
      await FileSaveHelper.showOpenChooser(
        context: context,
        path: path,
        mimeType: mimeType,
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

  Future<void> _openWithSystem(FileManagerEntry entry) async {
    final path = await context.read<FileManagerState>().prepareForOpen(
      entry,
      await _tempScope.createFile('file_manager_${entry.name}'),
    );
    if (path != null) {
      await FileSaveHelper.openFile(
        path,
        MimeTypeHelper.getMimeType(entry.name),
      );
    }
  }

  Future<void> _showDetails(FileManagerEntry entry) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FileManagerDetailsDialog(
        entry: entry,
        onOpen: () {
          Navigator.pop(context);
          _openEntry(entry);
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
      await _tempScope.createFile('file_manager_share_${entry.name}'),
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
    if (!state.selectedPaths.contains(entry.path)) state.toggleSelection(entry);
    await _confirmDelete();
  }

  Future<void> _confirmDelete() async {
    final state = context.read<FileManagerState>();
    final count = state.selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(AppLocalizations.of(context).fileManagerDeleteTitle),
        content: Text(
          AppLocalizations.of(context).fileManagerDeleteMessage(count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await state.deleteSelected();
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
    if (state == AppLifecycleState.resumed && _awaitingStorageAccess) {
      _awaitingStorageAccess = false;
      context.read<FileManagerState>().initialize();
    }
  }

  Future<String?> _showNameDialog(
    String title, {
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppLocalizations.of(context).commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<FileManagerState>();
    return PopScope(
      canPop: !state.canNavigateBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.canNavigateBack) state.goUp();
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
            onPressed: state.isLoading ? null : _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          if (state.canPaste)
            IconButton(
              tooltip: l10n.fileManagerPaste,
              onPressed:
                  state.isLoading ||
                      state.isRemote &&
                          state.connection?.protocol == FileManagerProtocol.ftp
                  ? null
                  : state.paste,
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
              onOpenLocal: state.openLocal,
              onOpenConnection: state.openConnection,
              onAddConnection: _addConnection,
              onRemoveConnection: _removeConnection,
              onRequestStorageAccess: _requestStorageAccess,
            );
            final explorer = FileManagerExplorer(
              state: state,
              onOpen: _openEntry,
              onOpenWithSystem: _openWithSystem,
              onDetails: _showDetails,
              onRename: _rename,
              onDelete: _delete,
              onCopy: state.copy,
              onCut: state.cut,
              onGoUp: state.goUp,
              onToggleFavorite: state.toggleFavorite,
              onToggleSelection: state.toggleSelection,
              onEnterSelectionMode: state.enterSelectionMode,
              onSelectAll: state.selectAll,
              onClearSelection: state.clearSelection,
              onDeleteSelection: _confirmDelete,
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

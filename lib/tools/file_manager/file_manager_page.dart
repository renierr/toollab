import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:tool_lab/tools/file_manager/widgets/file_manager_explorer.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_locations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage>
    with DisposeCleanup, WidgetsBindingObserver {
  late final TempFileScope _tempScope;

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
      context.read<FileManagerState>().initialize();
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
    await FileSaveHelper.showOpenChooser(
      context: context,
      path: path,
      mimeType: MimeTypeHelper.getMimeType(entry.name),
    );
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

  Future<void> _addConnection() async {
    final result = await showDialog<(FileManagerConnection, String)>(
      context: context,
      builder: (_) => const FileManagerConnectionDialog(),
    );
    if (result != null && mounted) {
      await context.read<FileManagerState>().saveConnection(
        result.$1,
        result.$2,
      );
    }
  }

  Future<void> _requestStorageAccess() async {
    await FileManagerStorageAccess.requestAllFilesAccess();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
    return ToolLayout(
      title: FileManagerTool.config.localizedName(l10n),
      actions: [
        if (FileManagerStorageAccess.isAndroid)
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
            onPressed: state.isLoading || state.isRemote ? null : state.paste,
            icon: Icon(
              state.clipboardIsCut
                  ? Icons.drive_file_move_outline
                  : Icons.content_paste_outlined,
            ),
          ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final locations = FileManagerLocations(
            state: state,
            onOpenLocal: state.openLocal,
            onOpenConnection: state.openConnection,
            onAddConnection: _addConnection,
            onRemoveConnection: state.removeConnection,
          );
          final explorer = FileManagerExplorer(
            state: state,
            onOpen: _openEntry,
            onRename: _rename,
            onDelete: state.delete,
            onCopy: state.copy,
            onCut: state.cut,
            onGoUp: state.goUp,
            onToggleFavorite: state.toggleFavorite,
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
    );
  }
}

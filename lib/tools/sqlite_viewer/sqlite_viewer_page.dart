import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/custom_notification.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'sqlite_viewer_state.dart';
import 'widgets/sqlite_open_view.dart';
import 'widgets/sqlite_schema_drawer.dart';
import 'widgets/sqlite_workspace.dart';

class SqliteViewerPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const SqliteViewerPage({super.key, this.sharedFile});

  @override
  State<SqliteViewerPage> createState() => _SqliteViewerPageState();
}

class _SqliteViewerPageState extends State<SqliteViewerPage>
    with DisposeCleanup {
  late final TempFileScope _scope;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    final state = context.read<SqliteViewerState>();
    state.attachScope(_scope);
    onDispose(state.closeDb);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SqliteViewerState>().scanInternalDatabases();
      final shared = widget.sharedFile;
      if (shared != null) _open(shared.path, shared.name);
    });

    final sharingSub = SharingService.instance.onSharedFile.listen(
      (file) => _open(file.path, file.name),
    );
    onDispose(sharingSub.cancel);
  }

  /// Android hands out SAF copies rather than writable originals, so every file
  /// opened there is treated as a snapshot.
  void _open(String path, String name) {
    context.read<SqliteViewerState>().openFile(
      path,
      name,
      isSnapshot: Platform.isAndroid,
    );
  }

  void _onFileSelected(XFile file) => _open(file.path, file.name);

  Future<void> _toggleEditMode() async {
    final state = context.read<SqliteViewerState>();
    final l10n = AppLocalizations.of(context);

    if (state.editMode) {
      await state.setEditMode(false);
      return;
    }
    if (!state.canEnableEditMode) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerEditNotAllowedInternal,
        isError: true,
      );
      return;
    }

    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.sqliteViewerEnableEditTitle,
      message: state.isTempCopy
          ? l10n.sqliteViewerEnableEditMessageCopy
          : l10n.sqliteViewerEnableEditMessage,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.sqliteViewerEnable,
    );
    if (confirmed != true || !mounted) return;

    final ok = await state.setEditMode(true);
    if (!ok && mounted) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerEditNotPossible,
        isError: true,
      );
    }
  }

  Future<void> _saveCopy() async {
    final state = context.read<SqliteViewerState>();
    final l10n = AppLocalizations.of(context);
    final path = await state.prepareExport();
    if (!mounted) return;
    if (path == null) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerSaveCopyFailed,
        isError: true,
      );
      return;
    }
    await FileSaveHelper.saveFileFromPath(
      context: context,
      sourcePath: path,
      suggestedName: state.exportName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SqliteViewerState>();
    final title = SqliteViewerTool.config.localizedName(l10n);

    if (!state.isOpen) {
      return ToolLayout(
        title: title,
        child: SqliteOpenView(
          onFileSelected: _onFileSelected,
          tempScope: _scope,
        ),
      );
    }

    final showDrawerButton = !ResponsiveLayout.isDesktop(context);

    return ToolLayout(
      title: state.displayName ?? title,
      scaffoldKey: _scaffoldKey,
      endDrawer: showDrawerButton ? const SqliteSchemaDrawer() : null,
      actions: [
        IconButton(
          icon: Icon(state.editMode ? Icons.lock_open : Icons.lock_outline),
          tooltip: state.editMode
              ? l10n.sqliteViewerEditModeOn
              : l10n.sqliteViewerEditModeOff,
          onPressed: state.isBusy ? null : _toggleEditMode,
        ),
        if (state.hasEdits && state.isTempCopy)
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: l10n.sqliteViewerSaveCopy,
            onPressed: _saveCopy,
          ),
        if (showDrawerButton)
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: l10n.sqliteViewerObjects,
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: state.closeDb,
        ),
      ],
      child: const SqliteWorkspace(),
    );
  }
}

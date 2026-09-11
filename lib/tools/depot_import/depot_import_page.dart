import 'dart:convert';

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'depot_import_state.dart';
import 'widgets/depot_activity_edit_dialog.dart';
import 'widgets/depot_import_toolbar.dart';
import 'widgets/depot_raw_text_dialog.dart';
import 'widgets/depot_statement_card.dart';

class DepotImportPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const DepotImportPage({super.key, this.sharedFile});

  @override
  State<DepotImportPage> createState() => _DepotImportPageState();
}

class _DepotImportPageState extends State<DepotImportPage> with DisposeCleanup {
  late final TempFileScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    final state = context.read<DepotImportState>();
    onDispose(() => Future.microtask(state.clear));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shared = widget.sharedFile;
      if (shared != null) _loadSharedFile(shared);
    });

    final sharingSub = SharingService.instance.onSharedFile.listen(
      _loadSharedFile,
    );
    onDispose(sharingSub.cancel);
  }

  void _loadSharedFile(SharedFile file) {
    context.read<DepotImportState>().addFiles([
      (path: file.path, name: file.name),
    ]);
  }

  void _onFilesSelected(List<XFile> files) {
    context.read<DepotImportState>().addFiles([
      for (final file in files) (path: file.path, name: file.name),
    ]);
  }

  Future<void> _pickMore() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (files.isNotEmpty && mounted) _onFilesSelected(files);
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<DepotImportState>();
    if (state.exportable.isEmpty) {
      FileSaveHelper.showErrorNotification(
        context: context,
        errorMessage: l10n.depotImportNothingToExport,
      );
      return;
    }

    final bytes = utf8.encode(state.buildCsv());
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'parqet-import.csv',
      bytes: bytes,
      successMessageAndroid: l10n.depotImportExported,
      successMessageGeneralBuilder: (path) =>
          '${l10n.depotImportExported}\n$path',
    );
  }

  Future<void> _edit(String id) async {
    final state = context.read<DepotImportState>();
    final statement = state.statements.firstWhere((s) => s.id == id);
    final activity = statement.activity;
    if (activity == null) return;

    final updated = await DepotActivityEditDialog.show(context, activity);
    if (updated != null) state.updateActivity(id, updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotImportState>();

    return ToolLayout(
      title: DepotImportTool.config.localizedName(l10n),
      child: state.isEmpty && !state.isImporting
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: FileDropZone(
                onFilesSelected: _onFilesSelected,
                multiple: true,
                allowedExtensions: const ['pdf'],
                allowedMimeTypes: const ['application/pdf'],
                useAndroidStreamingPicker: true,
                tempScope: _scope,
                typeLabel: l10n.depotImportTypeLabel,
                accentColor: DepotImportTool.config.accentColor,
                title: l10n.depotImportOpenTitle,
                subtitle: l10n.depotImportDropSubtitle,
                icon: Icons.account_balance_outlined,
              ),
            )
          : Column(
              children: [
                DepotImportToolbar(
                  activityCount: state.exportable.length,
                  issueCount: state.issueCount,
                  isImporting: state.isImporting,
                  importDone: state.importDone,
                  importTotal: state.importTotal,
                  onAdd: _pickMore,
                  onClear: state.clear,
                  onExport: _export,
                ),
                if (state.isImporting) const LinearProgressIndicator(),
                Expanded(
                  child: ReadableWidth(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: state.statements.length,
                      itemBuilder: (context, index) {
                        final statement = state.statements[index];
                        return DepotStatementCard(
                          statement: statement,
                          onToggle: () => state.toggleSelected(statement.id),
                          onEdit: () => _edit(statement.id),
                          onRemove: () => state.remove(statement.id),
                          onShowText: () => DepotRawTextDialog.show(
                            context,
                            fileName: statement.fileName,
                            text: statement.rawText,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

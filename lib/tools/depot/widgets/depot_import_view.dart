import 'dart:convert';

import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/custom_notification.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../config.dart';
import '../depot_import_state.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../parqet/parqet_api.dart';
import '../parqet/parqet_auth.dart';
import '../parqet/parqet_exception.dart';
import 'depot_activity_edit_dialog.dart';
import 'depot_import_toolbar.dart';
import 'depot_raw_text_dialog.dart';
import 'depot_settings_page.dart';
import 'depot_statement_card.dart';
import 'depot_upload_dialog.dart';

class DepotImportView extends StatefulWidget {
  final TempFileScope tempScope;

  const DepotImportView({super.key, required this.tempScope});

  @override
  State<DepotImportView> createState() => _DepotImportViewState();
}

class _DepotImportViewState extends State<DepotImportView> {
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

    final withIssues = state.exportable
        .where((s) => s.issues.isNotEmpty)
        .length;
    if (withIssues > 0 && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ResponsiveAlertDialog(
          title: Text(l10n.depotImportExportIssuesTitle),
          content: Text(l10n.depotImportExportIssuesBody(withIssues)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.depotImportExportAnyway),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;

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

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context);
    final importState = context.read<DepotImportState>();
    final portfolio = context.read<DepotPortfolioState>();
    await portfolio.ensureLoaded();
    final canWrite = portfolio.isConnected && await ParqetAuth.canWrite();
    if (!mounted) return;

    if (!canWrite) {
      final reconnect = await ConfirmActionDialog.show(
        context: context,
        title: l10n.depotUploadNeedsWriteTitle,
        message: portfolio.isConnected
            ? l10n.depotUploadNeedsWrite
            : l10n.depotUploadNotConnected,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.depotSettingsTitle,
        confirmColor: Theme.of(context).colorScheme.primary,
      );
      if (reconnect == true && mounted) await DepotSettingsPage.open(context);
      return;
    }
    if (importState.exportable.isEmpty) {
      showNotificationDialog(
        context,
        l10n.depotImportNothingToExport,
        isError: true,
      );
      return;
    }
    if (portfolio.portfolios.isEmpty) {
      showNotificationDialog(
        context,
        l10n.depotUploadNoPortfolio,
        isError: true,
      );
      return;
    }

    final portfolios = portfolio.portfolios;
    final target = await DepotUploadDialog.show(
      context,
      portfolios: portfolios,
      initialPortfolioId: portfolios.any((p) => p.id == portfolio.scope)
          ? portfolio.scope
          : portfolios.first.id,
      statements: importState.exportable,
    );
    if (target == null || !mounted) return;

    try {
      final summary = await importState.uploadToParqet(
        api: ParqetApi(clientId: portfolio.clientId),
        portfolioId: target.portfolioId,
        existing: target.existing,
      );
      if (!mounted) return;
      showNotificationDialog(
        context,
        l10n.depotUploadDone(
          summary.uploaded,
          summary.existing,
          summary.rejected,
        ),
        isError: summary.rejected > 0,
      );
      if (summary.uploaded > 0) await portfolio.sync();
    } on ParqetException catch (e) {
      errorLog('[DepotImportView] Upload failed: $e');
      if (!mounted) return;
      showNotificationDialog(
        context,
        DepotPortfolioLabels.error(l10n, e),
        isError: true,
      );
    }
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

    if (state.isEmpty && !state.isImporting) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: FileDropZone(
          onFilesSelected: _onFilesSelected,
          multiple: true,
          allowedExtensions: const ['pdf'],
          allowedMimeTypes: const ['application/pdf'],
          useAndroidStreamingPicker: true,
          tempScope: widget.tempScope,
          typeLabel: l10n.depotImportTypeLabel,
          accentColor: DepotTool.config.accentColor,
          title: l10n.depotImportOpenTitle,
          subtitle: l10n.depotImportDropSubtitle,
          icon: Icons.account_balance_outlined,
        ),
      );
    }

    return Column(
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
          onUpload: _upload,
          isUploading: state.isUploading,
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
                  upload: state.uploadOf(statement.id),
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
    );
  }
}

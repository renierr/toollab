import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/maintenance/export_backups_card.dart';
import 'package:tool_lab/pages/maintenance/import_backup_card.dart';
import 'package:tool_lab/pages/maintenance/temp_files_card.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/health_dashboard/health_database.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/custom_notification.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  Future<void> _exportDbFlow(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final appState = context.read<AppState>();
      final bytes = await appState.getDatabaseBytes();
      if (!context.mounted) return;

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'tool_lab_db_$timestamp.db',
        bytes: bytes,
        successMessageAndroid: l10n.coreDatabaseExportedAndroid,
        successMessageGeneralBuilder: (displayPath) =>
            l10n.coreDatabaseExportedGeneral(displayPath),
        errorMessageBuilder: (e) => l10n.coreDatabaseExportFailed(e.toString()),
      );
    } catch (e) {
      if (!context.mounted) return;
      FileSaveHelper.showErrorNotification(
        context: context,
        errorMessage: l10n.coreDatabaseExportFailed(e.toString()),
      );
    }
  }

  Future<void> _exportSettingsFlow(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final appState = context.read<AppState>();
      final settingsJson = appState.exportSettingsToJson();
      final bytes = Uint8List.fromList(utf8.encode(settingsJson));
      if (!context.mounted) return;

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'tool_lab_settings_$timestamp.json',
        bytes: bytes,
        successMessageAndroid: l10n.coreSettingsExportedAndroid,
        successMessageGeneralBuilder: (displayPath) =>
            l10n.coreSettingsExportedGeneral(displayPath),
        errorMessageBuilder: (e) => l10n.coreSettingsExportFailed(e.toString()),
      );
    } catch (e) {
      if (!context.mounted) return;
      FileSaveHelper.showErrorNotification(
        context: context,
        errorMessage: l10n.coreSettingsExportFailed(e.toString()),
      );
    }
  }

  Future<void> _importDbFlow(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    const typeGroup = XTypeGroup(label: 'SQLite Database', extensions: ['db']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    // Validate the picked file before any destructive action.
    try {
      await DatabaseService.instance.validateDatabaseFile(file.path);
    } catch (e) {
      if (!context.mounted) return;
      final reason = e is FormatException ? e.message : e.toString();
      showNotificationDialog(
        context,
        l10n.coreDatabaseImportInvalid(reason.toString()),
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.coreDatabaseImportConfirmTitle,
      message: l10n.coreDatabaseImportConfirmMessage,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonImport,
      confirmColor: AppTheme.statusRed,
    );
    if (confirmed != true) return;

    try {
      await DatabaseService.instance.importDatabaseFile(file.path);
      await HealthDatabase.instance.resetAfterDatabaseImport();
      if (!context.mounted) return;
      await context.read<AppState>().reloadFromDatabase();
      if (!context.mounted) return;
      showNotificationDialog(context, l10n.coreDatabaseImportSuccess);
    } catch (e) {
      if (!context.mounted) return;
      showNotificationDialog(
        context,
        l10n.coreDatabaseImportFailed(e.toString()),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.coreMaintenanceTitle)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExportBackupsCard(
                onExportDb: () => _exportDbFlow(context),
                onExportSettings: () => _exportSettingsFlow(context),
              ),
              const SizedBox(height: 16),
              const TempFilesCard(),
              const SizedBox(height: 16),
              ImportBackupCard(onImportDb: () => _importDbFlow(context)),
            ],
          ),
        ),
      ),
    );
  }
}

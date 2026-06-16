import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/maintenance/export_backups_card.dart';
import 'package:tool_lab/pages/maintenance/temp_files_card.dart';
import 'package:tool_lab/providers/app_state.dart';

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
            ],
          ),
        ),
      ),
    );
  }
}

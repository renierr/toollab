import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_dashboard_state.dart';
import '../health_database.dart';
import 'health_import_progress_dialog.dart';
import 'health_export_progress_dialog.dart';

class HealthBackupActions {
  static const _typeGroup = XTypeGroup(
    label: 'Health Dashboard SQLite backup',
    extensions: ['db'],
  );
  static const _jsonTypeGroup = XTypeGroup(
    label: 'Health Connect JSON export',
    extensions: ['json'],
  );
  static const _analysisTypeGroup = XTypeGroup(
    label: 'Health Connect analysis database',
    extensions: ['db'],
  );

  static Future<void> export(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ResponsiveAlertDialog(
        title: Text(l10n.healthDashboardExportBackup),
        content: Text(l10n.healthDashboardExportBackupWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonExport),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    HealthExportProgressDialog.show(context);
    final path = await context.read<HealthDashboardState>().exportBackup();
    if (!context.mounted) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: 'health_dashboard_backup.db',
      sourcePath: path,
      acceptedTypeGroups: const [_typeGroup],
    );
  }

  static Future<void> exportJson(BuildContext context) async {
    final path = await HealthDatabase.instance.exportHealthConnectJson();
    if (!context.mounted) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: 'health_connect_export.json',
      sourcePath: path,
      acceptedTypeGroups: const [_jsonTypeGroup],
    );
  }

  static Future<void> exportHealthConnectAnalysis(BuildContext context) async {
    await _exportHealthConnectData(context, fullHistory: true);
  }

  static Future<void> exportHealthConnectDiscovery(BuildContext context) async {
    await _exportHealthConnectData(context, fullHistory: false);
  }

  static Future<void> _exportHealthConnectData(
    BuildContext context, {
    required bool fullHistory,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    HealthImportProgressDialog.show(
      context,
      operation: HealthImportOperation.analysis,
    );
    try {
      final exportPath = fullHistory
          ? await context
                .read<HealthDashboardState>()
                .exportHealthConnectAnalysis()
          : await context
                .read<HealthDashboardState>()
                .exportHealthConnectDiscovery();
      if (!context.mounted) return;
      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: fullHistory
            ? 'health_connect_analysis.db'
            : 'health_connect_discovery.db',
        sourcePath: exportPath,
        acceptedTypeGroups: const [_analysisTypeGroup],
      );
    } catch (e) {
      errorLog('[HealthDashboard] Health Connect analysis export failed: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            fullHistory
                ? l10n.healthDashboardHealthConnectAnalysisFailed
                : l10n.healthDashboardHealthConnectDiscoveryFailed,
          ),
        ),
      );
    }
  }

  static Future<void> import(BuildContext context) async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ResponsiveAlertDialog(
        title: Text(l10n.healthDashboardImportBackup),
        content: Text(l10n.healthDashboardImportBackupWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.healthDashboardImportBackup),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      HealthImportProgressDialog.show(
        context,
        operation: HealthImportOperation.backup,
      );
      final imported = await context.read<HealthDashboardState>().importBackup(
        file.path,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.healthDashboardImportBackupSuccess(imported)),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.healthDashboardImportBackupFailed)),
        );
      }
    }
  }
}

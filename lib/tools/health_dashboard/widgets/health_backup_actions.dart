import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_dashboard_state.dart';
import '../store/health_models.dart';
import '../store/health_store.dart';
import 'health_import_progress_dialog.dart';
import 'health_export_progress_dialog.dart';

class HealthBackupActions {
  static const _fileName = 'health_dashboard_backup.db';
  static const _typeGroup = XTypeGroup(
    label: 'Health Dashboard SQLite backup',
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
    final destination = await _resolveDestination();
    if (destination == null && !Platform.isAndroid) return;
    if (!context.mounted) return;
    final notify = context.read<AppState>().systemNotificationsEnabled;
    HealthExportProgressDialog.show(context);
    final String? saved;
    try {
      saved = await context.read<HealthDashboardState>().exportBackup(
        destinationPath: destination,
        notifyOnSave: notify,
      );
    } catch (e) {
      errorLog('[HealthDashboard] Backup export failed: $e');
      if (context.mounted) {
        FileSaveHelper.showErrorNotification(
          context: context,
          errorMessage: l10n.healthDashboardExportBackupFailed,
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (saved == null) {
      FileSaveHelper.showErrorNotification(
        context: context,
        errorMessage: l10n.healthDashboardExportBackupFailed,
      );
      return;
    }
    FileSaveHelper.showSuccessNotification(
      context: context,
      savedPath: saved,
      androidDownloadMessage: l10n.healthDashboardExportBackupSavedDownloads,
      generalMessageBuilder: l10n.healthDashboardExportBackupSavedTo,
    );
  }

  /// Where the export writes directly. Desktop asks first so the database is
  /// written once instead of being copied out of temp afterwards; Android can
  /// only do the same with all-files access, and falls back to the temp copy.
  static Future<String?> _resolveDestination() async {
    if (!Platform.isAndroid) {
      final location = await getSaveLocation(
        suggestedName: _fileName,
        acceptedTypeGroups: const [_typeGroup],
      );
      return location?.path;
    }
    try {
      return await FileSaveHelper.createAndroidDownloadsFilePath(_fileName);
    } catch (e) {
      debugLog('[HealthDashboard] No direct Downloads path, using temp: $e');
      return null;
    }
  }

  static Future<void> import(BuildContext context) async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    // Read the marker before warning: an unusable file should fail before the
    // user is asked to agree to a wipe.
    final HealthBackupInfo info;
    try {
      info = await HealthStore.instance.readBackupInfo(file.path);
    } catch (e) {
      errorLog('[HealthDashboard] Not a health backup: $e');
      if (context.mounted) {
        _snack(context, l10n.healthDashboardImportBackupFailed);
      }
      return;
    }
    if (!context.mounted) return;
    if (info.isNewerThanApp) {
      _snack(context, l10n.healthDashboardImportBackupTooNew);
      return;
    }
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
            child: Text(l10n.healthDashboardImportBackupReplace),
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
      _snack(context, l10n.healthDashboardImportBackupSuccess(imported));
    } catch (e) {
      errorLog('[HealthDashboard] Backup restore failed: $e');
      if (context.mounted) {
        _snack(context, l10n.healthDashboardImportBackupFailed);
      }
    }
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
}

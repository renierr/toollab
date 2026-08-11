import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../health_connect_settings.dart';
import '../health_dashboard_state.dart';
import 'health_apps_page.dart';
import 'health_busy_dialog.dart';
import 'health_data_types_page.dart';
import 'health_import_progress_dialog.dart';
import 'health_store_status_tile.dart';

/// All Health Connect options live here so the dashboard settings page keeps a
/// single entry for them as more are added.
class HealthConnectSettingsPage extends StatelessWidget {
  const HealthConnectSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final healthState = context.watch<HealthDashboardState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardHealthConnectSettings)),
      body: ListView(
        children: [
          SettingsSectionLabel(title: l10n.healthDashboardSectionAccess),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(l10n.healthDashboardManageHealthConnect),
            subtitle: Text(l10n.healthDashboardManageHealthConnectSubtitle),
            trailing: healthState.isCollecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: healthState.isCollecting
                ? null
                : () => _openSystemSettings(context),
          ),
          SettingsSectionLabel(
            title: l10n.healthDashboardSectionSelect,
            description: l10n.healthDashboardSectionSelectHint,
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: Text(l10n.healthDashboardDataTypes),
            subtitle: Text(l10n.healthDashboardDataTypesSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HealthDataTypesPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.apps_rounded),
            title: Text(l10n.healthDashboardApps),
            subtitle: Text(l10n.healthDashboardAppsSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HealthAppsPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.travel_explore_rounded),
            title: Text(l10n.healthDashboardScanSources),
            subtitle: Text(l10n.healthDashboardScanSourcesSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _runDiscovery(context),
          ),
          SettingsSectionLabel(
            title: l10n.healthDashboardSectionCollect,
            description: l10n.healthDashboardSectionCollectHint,
          ),
          const HealthStoreStatusTile(),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.sync_alt_rounded),
            title: Text(l10n.healthDashboardAutoSync),
            subtitle: Text(l10n.healthDashboardAutoSyncSubtitle),
            value: healthState.autoHealthConnectSync,
            onChanged: healthState.isCollecting
                ? null
                : (value) => healthState.setAutoHealthConnectSync(value),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(l10n.healthDashboardImportSelected),
            subtitle: Text(l10n.healthDashboardImportSelectedSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _importIntoStore(context, restart: false),
          ),
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: Text(l10n.healthDashboardSyncChanges),
            subtitle: Text(l10n.healthDashboardSyncChangesSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _syncChanges(context),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: Text(l10n.healthDashboardImportRestart),
            subtitle: Text(l10n.healthDashboardImportRestartSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _importIntoStore(context, restart: true),
          ),
          SettingsSectionLabel(
            title: l10n.healthDashboardSectionMaintenance,
            description: l10n.healthDashboardSectionMaintenanceHint,
          ),
          ListTile(
            leading: const Icon(
              Icons.cleaning_services_outlined,
              color: AppTheme.statusRed,
            ),
            title: Text(l10n.healthDashboardPruneUnused),
            subtitle: Text(l10n.healthDashboardPruneUnusedSubtitle),
            trailing: healthState.isCollecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _pruneUnused(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _openSystemSettings(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      // Health Connect's per-app screen is signature-protected, so on a device
      // that exposes no settings action only app info opens - say so instead of
      // leaving the user wondering why they landed there.
      if (await HealthConnectSettings.open()) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.healthDashboardManageFellBack)),
        );
      }
    } catch (e, stackTrace) {
      errorLog(
        '[HealthDashboard] Failed to open Health Connect settings: $e\n$stackTrace',
      );
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.healthDashboardHealthConnectOpenFailed)),
        );
      }
    }
  }

  Future<void> _importIntoStore(
    BuildContext context, {
    required bool restart,
  }) async {
    final healthState = context.read<HealthDashboardState>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    // A full import of everything selected can run for hours. Reading the
    // selection first also catches the case where nothing is selected at all, in
    // which case the import would have quietly stored nothing.
    await healthState.loadSelection();
    if (!context.mounted) return;
    final confirmed = await _confirmFullImport(
      context,
      healthState.enabledTypeCount,
    );
    if (!confirmed || !context.mounted) return;
    HealthImportProgressDialog.show(
      context,
      operation: HealthImportOperation.healthConnect,
    );
    await healthState.importIntoStore(restart: restart);
    if (!context.mounted) return;
    if (healthState.permissionMissing) {
      await _offerGrantIfMissing(context);
      return;
    }
    if (healthState.error != null) {
      errorLog('[HealthDashboard] Store import error: ${healthState.error}');
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          healthState.error == null
              ? l10n.healthDashboardHealthConnectImported
              : l10n.healthDashboardHealthConnectImportFailed,
        ),
      ),
    );
  }

  Future<bool> _confirmFullImport(BuildContext context, int typeCount) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.healthDashboardImportConfirmTitle),
        content: Text(
          typeCount == 0
              ? l10n.healthDashboardImportConfirmNoTypes
              : l10n.healthDashboardImportConfirmBody(typeCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          if (typeCount > 0)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonOk),
            ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Confirmed because it deletes: a switched-off writer's rows are gone
  /// afterwards, and switching it back on will not bring them back without a
  /// fresh import.
  Future<void> _pruneUnused(BuildContext context) async {
    final healthState = context.read<HealthDashboardState>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    // The row count is read before the confirm so it names what will go.
    await healthState.loadSelection();
    if (!context.mounted) return;
    final disabled = healthState.healthApps
        .where((app) => !app.enabled)
        .toList();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.healthDashboardPruneUnused,
      message: disabled.isEmpty
          ? l10n.healthDashboardPruneUnusedConfirmNoApps
          : l10n.healthDashboardPruneUnusedConfirm(
              disabled.map((app) => app.package).join(', '),
            ),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.healthDashboardPruneUnusedConfirmAction,
    );
    if (confirmed != true || !context.mounted) return;
    final result = await healthState.pruneUnusedData();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? l10n.healthDashboardPruneUnusedFailed
              : l10n.healthDashboardPruneUnusedDone(result.rows),
        ),
      ),
    );
  }

  Future<void> _runDiscovery(BuildContext context) async {
    final healthState = context.read<HealthDashboardState>();
    await healthState.runDiscovery();
    if (!context.mounted) return;
    await _offerGrantIfMissing(context);
  }

  /// Every entry that reads Health Connect requests permission first; the
  /// request sheet is the only way an app can be granted access. When nothing
  /// comes back granted, offer the Health Connect screen rather than reporting a
  /// successful run over zero records.
  Future<void> _offerGrantIfMissing(BuildContext context) async {
    final healthState = context.read<HealthDashboardState>();
    if (!healthState.permissionMissing) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.healthDashboardPermissionNeeded),
        content: Text(l10n.healthDashboardPermissionNeededBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.healthDashboardOpenHealthConnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _openSystemSettings(context);
  }

  Future<void> _syncChanges(BuildContext context) async {
    final healthState = context.read<HealthDashboardState>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await healthState.syncChanges();
    if (!context.mounted) return;
    if (healthState.permissionMissing) {
      await _offerGrantIfMissing(context);
      return;
    }
    final message = result.needsFullImport
        ? l10n.healthDashboardFullImportNeeded
        : result.baselineEstablished
        ? l10n.healthDashboardBaselineEstablished
        : l10n.healthDashboardSyncChangesResult(
            result.upserted,
            result.deleted,
          );
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

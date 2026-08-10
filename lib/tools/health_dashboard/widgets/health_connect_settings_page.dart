import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../health_connect_settings.dart';
import '../health_dashboard_state.dart';
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
            leading: const Icon(Icons.travel_explore_rounded),
            title: Text(l10n.healthDashboardScanSources),
            subtitle: Text(l10n.healthDashboardScanSourcesSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : healthState.runDiscovery(),
          ),
          SettingsSectionLabel(
            title: l10n.healthDashboardSectionCollect,
            description: l10n.healthDashboardSectionCollectHint,
          ),
          const HealthStoreStatusTile(),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _openSystemSettings(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await HealthConnectSettings.open();
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
    HealthImportProgressDialog.show(
      context,
      operation: HealthImportOperation.healthConnect,
    );
    await healthState.importIntoStore(restart: restart);
    if (!context.mounted) return;
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

  Future<void> _syncChanges(BuildContext context) async {
    final healthState = context.read<HealthDashboardState>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await healthState.syncChanges();
    if (!context.mounted) return;
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

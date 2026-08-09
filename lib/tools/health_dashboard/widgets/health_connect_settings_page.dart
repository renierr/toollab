import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../health_connect_settings.dart';
import '../health_dashboard_state.dart';
import 'health_backup_actions.dart';
import 'health_busy_dialog.dart';
import 'health_import_progress_dialog.dart';

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
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: Text(l10n.healthDashboardImportHealthConnect),
            subtitle: Text(l10n.healthDashboardConnectHealthConnectSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _import(context),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.autorenew_rounded),
            title: Text(l10n.healthDashboardAutoHealthConnectSync),
            subtitle: Text(l10n.healthDashboardAutoHealthConnectSyncSubtitle),
            value: healthState.autoHealthConnectSync,
            onChanged: healthState.setAutoHealthConnectSync,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: Text(l10n.healthDashboardRepairHealthConnect),
            subtitle: Text(l10n.healthDashboardRepairHealthConnectSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : _repair(context),
          ),
          ListTile(
            leading: const Icon(Icons.travel_explore_rounded),
            title: Text(l10n.healthDashboardHealthConnectDiscovery),
            subtitle: Text(l10n.healthDashboardHealthConnectDiscoverySubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : HealthBackupActions.exportHealthConnectDiscovery(context),
          ),
          ListTile(
            leading: const Icon(Icons.biotech_outlined),
            title: Text(l10n.healthDashboardHealthConnectAnalysis),
            subtitle: Text(l10n.healthDashboardHealthConnectAnalysisSubtitle),
            onTap: () => healthState.isCollecting
                ? HealthBusyDialog.show(context)
                : HealthBackupActions.exportHealthConnectAnalysis(context),
          ),
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

  Future<void> _import(BuildContext context) async {
    final healthState = context.read<HealthDashboardState>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    HealthImportProgressDialog.show(
      context,
      operation: HealthImportOperation.healthConnect,
    );
    await healthState.connectHealthConnect();
    if (!context.mounted) return;
    if (healthState.error != null) {
      errorLog(
        '[HealthDashboard] Health Connect import error: ${healthState.error}',
      );
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

  Future<void> _repair(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.healthDashboardRepairHealthConnect),
        content: Text(l10n.healthDashboardResetHealthConnectDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.healthDashboardStartOver),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final healthState = context.read<HealthDashboardState>();
    final messenger = ScaffoldMessenger.of(context);
    HealthImportProgressDialog.show(
      context,
      operation: HealthImportOperation.healthConnect,
    );
    await healthState.repairHealthConnectCache();
    if (!context.mounted) return;
    if (healthState.error != null) {
      errorLog(
        '[HealthDashboard] Health Connect repair error: ${healthState.error}',
      );
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          healthState.error == null
              ? l10n.healthDashboardHealthConnectRepaired
              : l10n.healthDashboardHealthConnectRepairFailed,
        ),
      ),
    );
  }
}

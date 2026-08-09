import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';

import '../health_dashboard_state.dart';
import '../health_sync_delegate.dart';
import 'health_source_preferences_page.dart';
import 'health_backup_actions.dart';
import 'health_connect_settings_page.dart';

class HealthDashboardSettingsPage extends StatelessWidget {
  const HealthDashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final healthState = context.watch<HealthDashboardState>();
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardSettings)),
      body: ListView(
        children: [
          _SettingsSection(title: l10n.healthDashboardDataToShow),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.directions_run_outlined),
            title: Text(l10n.healthDashboardShowTreadmill),
            subtitle: Text(l10n.healthDashboardShowTreadmillSubtitle),
            value: healthState.showTreadmillWorkouts,
            onChanged: healthState.setShowTreadmillWorkouts,
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(l10n.healthDashboardSourcePreferences),
            subtitle: Text(l10n.healthDashboardSourcePreferencesSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HealthSourcePreferencesPage(),
              ),
            ),
          ),
          const Divider(height: 1),
          _SettingsSection(title: l10n.healthDashboardHealthConnectSettings),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(l10n.healthDashboardHealthConnectSettings),
            subtitle: Text(l10n.healthDashboardHealthConnectSettingsSubtitle),
            trailing: healthState.isCollecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HealthConnectSettingsPage(),
              ),
            ),
          ),
          const Divider(height: 1),
          _SettingsSection(title: l10n.healthDashboardBackup),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(l10n.healthDashboardExportBackup),
            subtitle: Text(l10n.healthDashboardExportBackupSubtitle),
            onTap: () => HealthBackupActions.export(context),
          ),
          ListTile(
            leading: const Icon(Icons.data_object_rounded),
            title: Text(l10n.healthDashboardExportJson),
            subtitle: Text(l10n.healthDashboardExportJsonSubtitle),
            onTap: () => HealthBackupActions.exportJson(context),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.healthDashboardImportBackup),
            subtitle: Text(l10n.healthDashboardImportBackupSubtitle),
            onTap: () => HealthBackupActions.import(context),
          ),
          const Divider(height: 1),
          _SettingsSection(title: l10n.healthDashboardCloudBackendSync),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(l10n.healthDashboardSyncNow),
            subtitle: Text(
              appState.syncEnabled
                  ? l10n.healthDashboardSyncEnabled
                  : l10n.healthDashboardSyncDisabled,
            ),
            trailing: appState.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => _sync(context),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final healthState = context.read<HealthDashboardState>();
    final appState = context.read<AppState>();

    try {
      await healthState.collect();
      await healthState.syncHealthConnect();
    } catch (e) {
      errorLog('[HealthDashboard] Health Connect sync failed: $e');
    }

    if (!appState.syncEnabled) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.healthDashboardHealthConnectImported)),
      );
      return;
    }
    if (appState.isSyncing) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.healthDashboardSyncInProgress)),
      );
      return;
    }
    try {
      await healthState.collect();
      await healthState.syncHealthConnect();
      final result = await appState.syncWithBackend([
        HealthDashboardSyncDelegate(),
      ]);
      if (!context.mounted) return;
      if (result == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.healthDashboardSyncNoChanges)),
        );
        return;
      }
      await context.read<HealthDashboardState>().load();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.healthDashboardSyncSuccess(
              result['pushed'] ?? 0,
              result['pulled'] ?? 0,
            ),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.healthDashboardSyncFailed)),
        );
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;

  const _SettingsSection({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

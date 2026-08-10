import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import 'health_backup_actions.dart';
import 'health_connect_settings_page.dart';

class HealthDashboardSettingsPage extends StatelessWidget {
  const HealthDashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final healthState = context.watch<HealthDashboardState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardSettings)),
      body: ListView(
        children: [
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
        ],
      ),
    );
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

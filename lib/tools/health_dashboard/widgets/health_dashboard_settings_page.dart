import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';

import '../health_dashboard_state.dart';
import '../health_sync_delegate.dart';

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
          const Divider(height: 1),
          _SettingsSection(title: l10n.healthDashboardSync),
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
            onTap: !appState.syncEnabled || appState.isSyncing
                ? null
                : () => _sync(context),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context.read<AppState>().syncWithBackend([
        HealthDashboardSyncDelegate(),
      ]);
      if (!context.mounted || result == null) return;
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

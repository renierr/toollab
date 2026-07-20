import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Settings hub for standalone single-tool builds. Mirrors the entries of the
/// full app's settings sheet that make sense without an overview: Appearance,
/// Maintenance, About, and Sync (only when the bundled tool has a sync
/// delegate). Each entry pushes an existing settings page.
class StandaloneSettingsPage extends StatelessWidget {
  const StandaloneSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tool = ToolRegistry.all.isNotEmpty ? ToolRegistry.all.first : null;
    final hasSync = tool?.syncDelegateFactory != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.coreSettingsDialogTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            if (hasSync) ...[
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: Text(l10n.coreSyncTitle),
                subtitle: Text(l10n.coreSettingsDialogSyncSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/sync-settings'),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: Text(l10n.coreMaintenanceTitle),
              subtitle: Text(l10n.coreSettingsDialogMaintenanceSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/maintenance'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.appearanceTitle),
              subtitle: Text(l10n.coreSettingsDialogAppearanceSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/appearance-settings'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.coreAboutTitle),
              subtitle: Text(l10n.coreSettingsDialogAboutSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/about'),
            ),
          ],
        ),
      ),
    );
  }
}

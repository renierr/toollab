import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/overview/open_with_defaults_dialog.dart';

class OverviewSettingsDialog extends StatelessWidget {
  const OverviewSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OverviewSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.coreSettingsDialogTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: Text(l10n.coreSyncTitle),
                subtitle: Text(l10n.coreSettingsDialogSyncSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/sync-settings');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: Text(l10n.coreMaintenanceTitle),
                subtitle: Text(l10n.coreSettingsDialogMaintenanceSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/maintenance');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shortcut_outlined),
                title: Text(l10n.coreShortcutsTitle),
                subtitle: Text(l10n.coreSettingsDialogShortcutsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/shortcut-settings');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_outlined),
                title: Text(l10n.coreOpenWithDefaultsTitle),
                subtitle: Text(l10n.coreSettingsDialogOpenWithSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  OpenWithDefaultsDialog.show(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.appearanceTitle),
                subtitle: Text(l10n.coreSettingsDialogAppearanceSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/appearance-settings');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.coreAboutTitle),
                subtitle: Text(l10n.coreSettingsDialogAboutSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/about');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              Text('Overview Settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Cloud Synchronization'),
                subtitle: const Text('Backup and sync tool data to the cloud'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/sync-settings');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('Maintenance Settings'),
                subtitle: const Text(
                  'Download database backups and settings JSON',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/maintenance');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shortcut_outlined),
                title: const Text('Tool Shortcuts'),
                subtitle: const Text(
                  'Pin shortcuts or manage app drawer icons',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/shortcut-settings');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: const Text(
                  'Theme, compact view, notifications, sorting',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/appearance-settings');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: const Text('Version, licenses, and app info'),
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

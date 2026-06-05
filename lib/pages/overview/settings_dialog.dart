import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/providers/app_state.dart';

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
    final appState = context.watch<AppState>();

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
              SwitchListTile(
                title: const Text('Compact View'),
                subtitle: const Text('Smaller cards, more tools per row'),
                value: appState.compactMode,
                onChanged: (_) => appState.toggleCompactMode(),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Sort by'),
                trailing: DropdownButton<String>(
                  value: appState.sortBy,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'recent', child: Text('Recent')),
                    DropdownMenuItem(
                      value: 'order',
                      child: Text('Default order'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                  ],
                  onChanged: (value) {
                    if (value != null) appState.setSortBy(value);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: appState.themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) appState.setThemeMode(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

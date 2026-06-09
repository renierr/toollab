import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/providers/app_state.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.brightness_6_outlined,
                        color: theme.colorScheme.primary,
                      ),
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
                          if (value != null) {
                            context.read<AppState>().setThemeMode(value);
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Compact View'),
                      subtitle: const Text('Smaller cards, more tools per row'),
                      value: appState.compactMode,
                      onChanged: (_) =>
                          context.read<AppState>().toggleCompactMode(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('System Notifications'),
                      subtitle: const Text(
                        'Enable or disable system notifications',
                      ),
                      value: appState.systemNotificationsEnabled,
                      onChanged: (value) => context
                          .read<AppState>()
                          .setSystemNotificationsEnabled(value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text('Sort by'),
                      trailing: DropdownButton<String>(
                        value: appState.sortBy,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'recent',
                            child: Text('Recent'),
                          ),
                          DropdownMenuItem(
                            value: 'order',
                            child: Text('Default order'),
                          ),
                          DropdownMenuItem(value: 'name', child: Text('Name')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            context.read<AppState>().setSortBy(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

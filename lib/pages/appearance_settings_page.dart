import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
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
                      title: Text(l10n.settingsTheme),
                      trailing: DropdownButton<ThemeMode>(
                        value: appState.themeMode,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text(l10n.settingsThemeSystem),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text(l10n.settingsThemeLight),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text(l10n.settingsThemeDark),
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
                    ListTile(
                      leading: Icon(
                        Icons.translate_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.settingsLanguage),
                      trailing: DropdownButton<String>(
                        value: appState.locale?.languageCode ?? '',
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(l10n.settingsLanguageSystem),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(l10n.settingsLanguageEnglish),
                          ),
                          DropdownMenuItem(
                            value: 'de',
                            child: Text(l10n.settingsLanguageGerman),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          context.read<AppState>().setLocale(
                            value.isEmpty ? null : Locale(value),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(l10n.settingsCompactView),
                      subtitle: Text(l10n.settingsCompactViewSubtitle),
                      value: appState.compactMode,
                      onChanged: (_) =>
                          context.read<AppState>().toggleCompactMode(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(l10n.settingsSystemNotifications),
                      subtitle: Text(l10n.settingsSystemNotificationsSubtitle),
                      value: appState.systemNotificationsEnabled,
                      onChanged: (value) => context
                          .read<AppState>()
                          .setSystemNotificationsEnabled(value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(l10n.settingsLowLatencyAudio),
                      subtitle: Text(l10n.settingsLowLatencyAudioSubtitle),
                      value: appState.lowLatencyAudio,
                      onChanged: (value) =>
                          context.read<AppState>().setLowLatencyAudio(value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: Text(l10n.settingsSortBy),
                      trailing: DropdownButton<String>(
                        value: appState.sortBy,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: 'recent',
                            child: Text(l10n.settingsSortRecent),
                          ),
                          DropdownMenuItem(
                            value: 'order',
                            child: Text(l10n.settingsSortDefaultOrder),
                          ),
                          DropdownMenuItem(
                            value: 'name',
                            child: Text(l10n.settingsSortName),
                          ),
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

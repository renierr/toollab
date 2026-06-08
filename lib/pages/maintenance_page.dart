import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  Future<void> _exportDbFlow(BuildContext context) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final appState = context.read<AppState>();
      final bytes = await appState.getDatabaseBytes();
      if (!context.mounted) return;

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'tool_lab_db_$timestamp.db',
        bytes: bytes,
        successMessageAndroid:
            'Database exported to Downloads folder successfully.',
        successMessageGeneralBuilder: (displayPath) =>
            'Database exported to $displayPath successfully.',
        errorMessageBuilder: (e) => 'Database export failed: $e',
      );
    } catch (e) {
      if (!context.mounted) return;
      FileSaveHelper.showErrorNotification(
        context: context,
        errorMessage: 'Database export failed: $e',
      );
    }
  }

  Future<void> _exportSettingsFlow(BuildContext context) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final appState = context.read<AppState>();
      final settingsJson = appState.exportSettingsToJson();
      final bytes = Uint8List.fromList(utf8.encode(settingsJson));
      if (!context.mounted) return;

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'tool_lab_settings_$timestamp.json',
        bytes: bytes,
        successMessageAndroid:
            'Settings exported to Downloads folder successfully.',
        successMessageGeneralBuilder: (displayPath) =>
            'Settings exported to $displayPath successfully.',
        errorMessageBuilder: (e) => 'Settings export failed: $e',
      );
    } catch (e) {
      if (!context.mounted) return;
      FileSaveHelper.showErrorNotification(
        context: context,
        errorMessage: 'Settings export failed: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Settings')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.settings_suggest,
                        color: AppTheme.accentBlue,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Maintenance & Backups',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Download database backups and global settings JSON for safe keeping or migration to another device.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Export card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.backup_outlined,
                            color: AppTheme.accentGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Export & Backups',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save your SQLite database and application settings directly to your device local files.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Export DB Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _exportDbFlow(context),
                          icon: const Icon(Icons.download),
                          label: const Text(
                            'Export SQLite Database (.db)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Export Settings Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _exportSettingsFlow(context),
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text(
                            'Export Shared Preferences (.json)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Temp files card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cleaning_services_outlined,
                            color: AppTheme.statusAmber,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Temp Files',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: TempFileManager.trackedBytes(),
                        builder: (context, snapshot) {
                          final count = TempFileManager.trackedCount;
                          final size = snapshot.hasData
                              ? FormatHelper.fileSize(snapshot.data!)
                              : '...';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$count file(s) using $size',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.statusRed,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await TempFileManager.cleanAll();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Temp files cleaned up',
                                            ),
                                          ),
                                        );
                                      (context as Element).markNeedsBuild();
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text(
                                    'Clean Up Temp Files',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

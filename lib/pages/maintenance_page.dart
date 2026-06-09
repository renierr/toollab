import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/sharing_service.dart';

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

              // Open-with defaults card
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
                            Icons.open_in_new_outlined,
                            color: AppTheme.accentPurple,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open with Defaults',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Default tool associations for shared files. '
                        'Reset them to always show the chooser dialog.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, String>>(
                        future: SharingService.instance.getAllDefaultTools(),
                        builder: (context, snapshot) {
                          final defaults = snapshot.data ?? {};
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          if (defaults.isEmpty) {
                            return Text(
                              'No default associations set.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return Column(
                            children: [
                              ...defaults.entries.map((e) {
                                final tool = ToolRegistry.all.where(
                                  (t) => t.id == e.value,
                                );
                                final toolName = tool.isNotEmpty
                                    ? tool.first.name
                                    : e.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 16,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${e.key} → $toolName',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.statusAmber,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Reset All Defaults?',
                                        ),
                                        content: const Text(
                                          'This will clear all "always open with" '
                                          'associations. The chooser dialog will '
                                          'appear next time you open a shared file.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Reset'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && context.mounted) {
                                      await SharingService.instance
                                          .clearAllDefaultTools();
                                      messenger
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Default associations cleared',
                                            ),
                                          ),
                                        );
                                      (context as Element).markNeedsBuild();
                                    }
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text(
                                    'Reset All Defaults',
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
              const SizedBox(height: 16),

              // Open-with defaults card
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
                            Icons.open_in_new_outlined,
                            color: AppTheme.accentPurple,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open with Defaults',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Default tool associations for shared files. '
                        'Reset them to always show the chooser dialog.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, String>>(
                        future: SharingService.instance.getAllDefaultTools(),
                        builder: (context, snapshot) {
                          final defaults = snapshot.data ?? {};
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          if (defaults.isEmpty) {
                            return Text(
                              'No default associations set.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return Column(
                            children: [
                              ...defaults.entries.map((e) {
                                final tool = ToolRegistry.all.where(
                                  (t) => t.id == e.value,
                                );
                                final toolName = tool.isNotEmpty
                                    ? tool.first.name
                                    : e.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 16,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${e.key} → $toolName',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.statusAmber,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Reset All Defaults?',
                                        ),
                                        content: const Text(
                                          'This will clear all "always open with" '
                                          'associations. The chooser dialog will '
                                          'appear next time you open a shared file.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Reset'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && context.mounted) {
                                      await SharingService.instance
                                          .clearAllDefaultTools();
                                      messenger
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Default associations cleared',
                                            ),
                                          ),
                                        );
                                      (context as Element).markNeedsBuild();
                                    }
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text(
                                    'Reset All Defaults',
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

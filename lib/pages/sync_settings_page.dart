import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/providers/app_state.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  late final AppState _appState;
  late TextEditingController _serverUrlController;
  late TextEditingController _userIdController;

  bool _isSaving = false;
  bool _isSyncingLocal = false;
  String? _syncMessage;
  bool _syncSuccess = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
    _serverUrlController = TextEditingController(text: _appState.syncServerUrl);
    _userIdController = TextEditingController(text: _appState.syncUserId);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _appState.saveSyncSettings(
        enabled: _appState.syncEnabled,
        url: _serverUrlController.text.trim(),
        userId: _userIdController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _triggerManualSync() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSyncingLocal = true;
      _syncMessage = null;
    });

    try {
      // First save settings so the sync service uses the latest entered values
      await _appState.saveSyncSettings(
        enabled: true,
        url: _serverUrlController.text.trim(),
        userId: _userIdController.text.trim(),
      );

      // In the future, individual tool page states register their delegates in appState
      final results = await _appState.syncWithBackend(_appState.syncDelegates);

      if (!mounted) return;

      setState(() {
        _syncSuccess = true;
        if (results != null) {
          _syncMessage =
              'Sync completed. Pulled: ${results['pulled']}, Pushed: ${results['pushed']}, Deleted: ${results['deleted']}.';
        } else {
          _syncMessage = 'Sync failed. Server URL is empty.';
          _syncSuccess = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncSuccess = false;
        _syncMessage = 'Sync failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingLocal = false;
        });
      }
    }
  }

  String _formatLastSynced(int timestamp) {
    if (timestamp == 0) {
      return 'Never synced';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return 'Last synced: ${date.year}-$month-$day $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final enabled = appState.syncEnabled;
    final syncing = appState.isSyncing || _isSyncingLocal;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Synchronization')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info block
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_sync_outlined,
                          color: AppTheme.accentBlue,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync data across devices',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enabling cloud sync lets you back up your tools data and sync seamlessly to a centralized server.',
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

                // Enable toggle card
                Card(
                  margin: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: const Text(
                      'Enable Synchronization',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      enabled ? 'Syncing active' : 'Syncing disabled',
                      style: TextStyle(
                        color: enabled ? AppTheme.accentGreen : null,
                        fontWeight: enabled ? FontWeight.bold : null,
                      ),
                    ),
                    value: enabled,
                    onChanged: (val) {
                      appState.setSyncEnabled(val);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Configuration card
                AnimatedOpacity(
                  opacity: enabled ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Server Credentials',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _serverUrlController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Server Base URL',
                                hintText: 'http://localhost:3000',
                                prefixIcon: Icon(Icons.dns_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (enabled &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Server URL is required when sync is enabled';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _userIdController,
                              decoration: const InputDecoration(
                                labelText: 'User ID',
                                hintText: 'Enter your username or user ID',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (enabled &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'User ID is required when sync is enabled';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sync action card
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Status', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _formatLastSynced(appState.syncLastSynced),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                            onPressed: (syncing || !enabled)
                                ? null
                                : _triggerManualSync,
                            icon: syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(
                              syncing ? 'Syncing...' : 'Sync Now',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (_syncMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _syncSuccess
                                  ? AppTheme.accentGreen.withValues(alpha: 0.1)
                                  : AppTheme.accentRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _syncSuccess
                                    ? AppTheme.accentGreen.withValues(
                                        alpha: 0.3,
                                      )
                                    : AppTheme.accentRed.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _syncSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: _syncSuccess
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentRed,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _syncMessage!,
                                    style: TextStyle(
                                      color: _syncSuccess
                                          ? AppTheme.accentGreen
                                          : AppTheme.accentRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: const Text(
                      'Save Configuration',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_sync_switches.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage>
    with DisposeCleanup {
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
    onDispose(_serverUrlController.dispose);
    onDispose(_userIdController.dispose);
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.coreSyncSettingsSaved),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.coreSyncSettingsSaveFailed(e.toString())),
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
      await _appState.saveSyncSettings(
        enabled: true,
        url: _serverUrlController.text.trim(),
        userId: _userIdController.text.trim(),
      );

      final results = await _appState.syncWithBackend(_appState.syncDelegates);

      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      setState(() {
        _syncSuccess = true;
        if (results != null) {
          _syncMessage = l10n.coreSyncCompleted(
            results['pulled'].toString(),
            results['pushed'].toString(),
            results['deleted'].toString(),
          );
        } else {
          _syncMessage = l10n.coreSyncFailedNoUrl;
          _syncSuccess = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _syncSuccess = false;
        _syncMessage = l10n.coreSyncFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingLocal = false;
        });
      }
    }
  }

  String _formatLastSynced(int timestamp, AppLocalizations l10n) {
    if (timestamp == 0) {
      return l10n.coreSyncNeverSynced;
    }
    return l10n.coreSyncLastSynced(
      FormatHelper.epoch(timestamp, style: DateStyle.dateTimeSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final enabled = appState.syncEnabled;
    final syncing = appState.isSyncing || _isSyncingLocal;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.coreSyncTitle)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                l10n.coreSyncAcrossDevicesTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.coreSyncAcrossDevicesSubtitle,
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

                Card(
                  margin: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: Text(
                      l10n.coreSyncEnableTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      enabled ? l10n.coreSyncActive : l10n.coreSyncDisabled,
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
                              l10n.coreSyncServerCredentials,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _serverUrlController,
                              keyboardType: TextInputType.url,
                              decoration: InputDecoration(
                                labelText: l10n.coreSyncServerBaseUrl,
                                hintText: 'http://localhost:3000',
                                prefixIcon: const Icon(Icons.dns_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (enabled &&
                                    (v == null || v.trim().isEmpty)) {
                                  return l10n.coreSyncServerUrlRequired;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _userIdController,
                              decoration: InputDecoration(
                                labelText: l10n.coreSyncUserId,
                                hintText: l10n.coreSyncUserIdHint,
                                prefixIcon: const Icon(Icons.person_outline),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedOpacity(
                  opacity: enabled ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: const ToolSyncSwitches(),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.coreSyncStatusTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatLastSynced(appState.syncLastSynced, l10n),
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
                              syncing ? l10n.coreSyncSyncing : l10n.coreSyncNow,
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
                const SizedBox(height: 16),

                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.accentBlue,
                    ),
                    title: Text(l10n.coreSyncStatsTitle),
                    subtitle: Text(l10n.coreSyncStatsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/sync-stats'),
                  ),
                ),
                const SizedBox(height: 24),

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
                    label: Text(
                      l10n.coreSyncSaveConfiguration,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

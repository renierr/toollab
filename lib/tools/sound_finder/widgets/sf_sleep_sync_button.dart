import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';

import '../config.dart';
import '../sleep_sync_delegate.dart';

class SfSleepSyncButton extends StatefulWidget {
  const SfSleepSyncButton({super.key});

  @override
  State<SfSleepSyncButton> createState() => _SfSleepSyncButtonState();
}

class _SfSleepSyncButtonState extends State<SfSleepSyncButton> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // Catches up on a session whose sync after recording failed, e.g. offline.
    // After the first frame, because the sync notifies AppState right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (!appState.syncEnabled ||
          !appState.syncsTool(SoundFinderTool.config.id)) {
        return;
      }
      appState.syncWithBackend([SleepSyncDelegate()]).catchError((Object e) {
        errorLog('[SfSleepSyncButton] Auto-sync on open failed: $e');
        return null;
      });
    });
  }

  Future<void> _sync() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    if (!appState.isToolSyncEnabled(SoundFinderTool.config.id)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.coreSyncToolDisabled)),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final result = await appState.syncWithBackend([SleepSyncDelegate()]);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.sfSleepSyncedResult(
              result?['pulled'] ?? 0,
              result?['pushed'] ?? 0,
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sfSleepSyncFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.syncEnabled || appState.syncServerUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: AppLocalizations.of(context).sfSleepSync,
      onPressed: _syncing ? null : _sync,
      icon: _syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
    );
  }
}

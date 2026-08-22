import 'dart:io';

import 'package:tool_lab/core/background_task.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sync_service.dart';

/// The all-tools counterpart of a tool's own background sync: one unattended
/// run that pushes and pulls every sync-capable tool whose own switch is on.
///
/// Repeats `AppState.syncWithBackend`'s gates - global cloud sync, a configured
/// server, the per-tool switch - rather than calling it: `AppState` is a
/// provider, and a scheduled run has no widget tree to read one from.
class BackendSyncTask {
  BackendSyncTask._();

  static const _settingSyncEnabled = 'sync_enabled';

  static final BackgroundTask task = BackgroundTask(
    id: 'backend-sync',
    defaultInterval: const Duration(hours: 24),
    requiresNetwork: true,
    run: _run,
  );

  static Future<BackgroundTaskResult> _run() async {
    if (!Platform.isAndroid) {
      return const BackgroundTaskResult.skipped('Android only');
    }
    final settings = await SettingsService.init();
    if (!settings.getSyncEnabled()) {
      return const BackgroundTaskResult.skipped('Cloud sync disabled');
    }
    final url = settings.getSyncServerUrl();
    if (url.isEmpty) {
      return const BackgroundTaskResult.skipped('No server URL');
    }
    if (!await SyncService.isBackendAvailable(url)) {
      return const BackgroundTaskResult.failed('Backend server unreachable');
    }

    int pulled = 0;
    int pushed = 0;
    int deleted = 0;
    var tools = 0;
    final failures = <String>[];
    for (final tool in ToolRegistry.all) {
      final delegateFactory = tool.syncDelegateFactory;
      if (delegateFactory == null) continue;
      final enabled = await DatabaseService.instance.getSetting(
        tool.id,
        _settingSyncEnabled,
      );
      if (enabled == 'false') continue;
      tools++;
      try {
        final result = await SyncService.sync(
          baseUrl: url,
          userId: settings.getSyncUserId(),
          delegate: delegateFactory(),
          backendAlreadyChecked: true,
        );
        pulled += result['pulled'] ?? 0;
        pushed += result['pushed'] ?? 0;
        deleted += result['deleted'] ?? 0;
      } catch (e) {
        // One broken tool must not cost the others their run.
        failures.add('${tool.id}: $e');
      }
    }
    if (tools == 0) {
      return const BackgroundTaskResult.skipped('No tools enabled');
    }

    final detail =
        '$tools tools; pushed $pushed, pulled $pulled, deleted $deleted';
    if (failures.isNotEmpty) {
      return BackgroundTaskResult.failed('$detail; ${failures.join('; ')}');
    }
    await settings.setSyncLastSynced(DateTime.now().millisecondsSinceEpoch);
    return BackgroundTaskResult.done(detail);
  }
}

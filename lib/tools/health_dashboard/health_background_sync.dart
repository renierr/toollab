import 'dart:io';

import 'package:tool_lab/core/background_task.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'collectors/health_connect_catch_up.dart';
import 'config.dart';
import 'health_sync_delegate.dart';

/// The tool's unattended run: one Health Connect catch-up, then the backend
/// sync - the same two steps the open tool does, in the same order, so a device
/// nobody touches for a week still has both halves up to date.
///
/// Reading Health Connect from here is what `READ_HEALTH_DATA_IN_BACKGROUND`
/// buys. The permission only lifts the foreground requirement, though: it grants
/// no wakeup of its own, which is why this is a [BackgroundTask] and not a timer.
class HealthBackgroundSync {
  HealthBackgroundSync._();

  /// Not const because the id is derived from the tool id, which lives in the
  /// `config.dart` that declares this task in turn.
  static final BackgroundTask task = BackgroundTask(
    id: '${HealthDashboardTool.config.id}-sync',
    defaultInterval: const Duration(hours: 4),
    // Health Connect is on the device, so an offline run still has the whole
    // import half to do. The backend half reports its own failure instead, which
    // gets the run retried ahead of the next interval.
    requiresNetwork: false,
    run: _run,
  );

  static Future<BackgroundTaskResult> _run() async {
    if (!Platform.isAndroid) {
      return const BackgroundTaskResult.skipped('Android only');
    }
    final diff = await const HealthConnectCatchUp().run();
    final stored = diff.upserted + (diff.recovered ?? 0);
    final imported = 'imported $stored, deleted ${diff.deleted}';

    // Recovery already ran and still could not place a token; only a full import
    // from inside the tool fixes that, but a retry costs nothing and the next
    // one may land.
    if (diff.needsFullImport) {
      return const BackgroundTaskResult.failed(
        'Health Connect change token rejected',
      );
    }

    try {
      final synced = await _syncBackend();
      return BackgroundTaskResult.done(
        synced == null ? imported : '$imported; $synced',
      );
    } catch (e) {
      errorLog('[HealthBackgroundSync] Backend sync failed: $e');
      return BackgroundTaskResult.failed('$imported; backend failed: $e');
    }
  }

  /// Repeats `AppState.syncWithBackend`'s gate - a configured server plus this
  /// tool's own sync switch - rather than calling it: `AppState` is a provider,
  /// and a scheduled run has no widget tree to read one from. Returns null when
  /// the gate is closed, which is not a failure.
  static Future<String?> _syncBackend() async {
    final settings = await SettingsService.init();
    if (!settings.getSyncEnabled()) return null;
    final url = settings.getSyncServerUrl();
    if (url.isEmpty) return null;
    final enabled = await DatabaseService.instance.getSetting(
      HealthDashboardTool.config.id,
      DatabaseService.toolSyncEnabledKey,
    );
    if (!DatabaseService.isToolSyncEnabled(enabled)) return null;

    final result = await SyncService.sync(
      baseUrl: url,
      userId: settings.getSyncUserId(),
      delegate: HealthSyncDelegate(),
    );
    await settings.setSyncLastSynced(DateTime.now().millisecondsSinceEpoch);
    return 'pushed ${result['pushed'] ?? 0}, pulled ${result['pulled'] ?? 0}';
  }
}

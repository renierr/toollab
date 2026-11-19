import 'dart:io';

import 'package:tool_lab/core/background_task.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/todo_operations.dart';
import 'package:tool_lab/tools/todo/todo_publisher.dart';
import 'package:tool_lab/tools/todo/todo_sync_delegate.dart';

class TodoBackground {
  TodoBackground._();

  static final BackgroundTask task = BackgroundTask(
    id: '${TodoTool.config.id}-refresh',
    defaultInterval: const Duration(hours: 6),
    run: _run,
  );

  /// Applies queued widget/notification actions, syncs, then extends the
  /// reminder horizon so recurring reminders never run dry.
  static Future<BackgroundTaskResult> _run() async {
    if (!Platform.isAndroid) {
      return const BackgroundTaskResult.skipped('Android only');
    }
    final applied = await TodoOperations.applyPendingActions();
    await TodoOperations.cleanup(await TodoOperations.loadCleanupDays());
    String synced = 'sync off';
    try {
      synced = await syncIfEnabled() ?? synced;
    } catch (e) {
      errorLog('[TodoBackground] sync failed: $e');
      synced = 'sync failed: $e';
    }
    await TodoPublisher.publishFromDatabase();
    return BackgroundTaskResult.done(
      '${applied ? 'actions applied; ' : ''}$synced',
    );
  }

  /// Repeats `AppState.syncWithBackend`'s gate, since neither a background run
  /// nor the tool state can read the provider. Null when the gate is closed.
  static Future<String?> syncIfEnabled() async {
    final settings = await SettingsService.init();
    if (!settings.getSyncEnabled()) return null;
    final url = settings.getSyncServerUrl();
    if (url.isEmpty) return null;
    final enabled = await DatabaseService.instance.getSetting(
      TodoTool.config.id,
      DatabaseService.toolSyncEnabledKey,
    );
    if (!DatabaseService.isToolSyncEnabled(enabled)) return null;
    final result = await SyncService.sync(
      baseUrl: url,
      userId: settings.getSyncUserId(),
      delegate: TodoSyncDelegate(),
    );
    return 'pushed ${result['pushed'] ?? 0}, pulled ${result['pulled'] ?? 0}';
  }
}

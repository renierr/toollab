import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/core/background_task.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:workmanager/workmanager.dart';

import 'database_service.dart';

export 'package:tool_lab/core/background_task.dart';

/// Runs tool work on a schedule while the app is closed, on Android's
/// WorkManager and in a headless Flutter engine.
///
/// Tools declare their work as a [BackgroundTask] in `config.dart`; nothing here
/// knows about any individual tool. Two properties of where that work runs shape
/// the whole API: there is no UI (so no dialogs and no permission prompts), and
/// a scheduled run is a *second isolate* with its own database connection (so
/// runs take a lock and report through the database rather than through memory).
///
/// What the platform promises is a floor on the interval, not a schedule. In
/// Doze a run is deferred to the next maintenance window, which can be hours
/// late; nothing short of a foreground service changes that, so intervals here
/// are "at most this often", not "every".
class BackgroundTaskService {
  BackgroundTaskService._();

  static const String _logPrefix = 'BackgroundTaskService';

  /// Not a tool id: schedules and results of every tool's tasks share one
  /// namespace in the settings table, the way `SettingsService` uses `_app`.
  static const String _scope = '_background_tasks';
  static const String _intervalSuffix = 'interval_minutes';
  static const String _statusSuffix = 'last_status';
  static const String _lockSuffix = 'lock_started_at';

  /// WorkManager's own floor for periodic work. Anything shorter would need
  /// chained one-off work and would still be Doze-deferred, so it is clamped
  /// rather than worked around.
  static const Duration minimumInterval = Duration(minutes: 15);

  /// A run that never reported back is assumed dead after this, so a process
  /// killed mid-task cannot block every later run.
  static const Duration _lockTimeout = Duration(minutes: 15);

  /// What settings UIs offer. Kept here so every tool's picker has the same
  /// steps instead of inventing its own.
  static const List<Duration> intervalChoices = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
    Duration(hours: 24),
  ];

  static bool get isSupported => Platform.isAndroid;

  static List<BackgroundTask> get tasks => [
    for (final tool in ToolRegistry.all) ...?tool.backgroundTasks?.call(),
  ];

  static BackgroundTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Call once from `main`. Registering the dispatcher is not enough on its own:
  /// WorkManager keeps its queue across reboots and app updates, but a task
  /// whose interval changed, or that was added by an update, is only picked up
  /// by re-applying the stored schedules.
  static Future<void> init() async {
    if (!isSupported) return;
    try {
      await Workmanager().initialize(backgroundTaskDispatcher);
    } catch (e) {
      errorLog('[$_logPrefix] Initialization failed: $e');
      return;
    }
    for (final task in tasks) {
      try {
        await _apply(task, await interval(task));
      } catch (e) {
        errorLog('[$_logPrefix] Scheduling ${task.id} failed: $e');
      }
    }
  }

  /// The interval a task runs at, or null when the user turned it off. An
  /// unconfigured task falls back to its own default, so shipping one enabled
  /// needs no migration.
  static Future<Duration?> interval(BackgroundTask task) async {
    final stored = await DatabaseService.instance.getSetting(
      _scope,
      _key(task.id, _intervalSuffix),
    );
    if (stored == null) return task.defaultInterval;
    final minutes = int.tryParse(stored) ?? 0;
    return minutes <= 0 ? null : Duration(minutes: minutes);
  }

  /// Pass null to turn the task off.
  static Future<void> setInterval(
    BackgroundTask task,
    Duration? interval,
  ) async {
    await DatabaseService.instance.setSetting(
      _scope,
      _key(task.id, _intervalSuffix),
      '${interval?.inMinutes ?? 0}',
    );
    await _apply(task, interval);
  }

  static Future<BackgroundTaskStatus?> lastStatus(BackgroundTask task) async {
    final stored = await DatabaseService.instance.getSetting(
      _scope,
      _key(task.id, _statusSuffix),
    );
    if (stored == null) return null;
    try {
      return BackgroundTaskStatus.fromJson(
        jsonDecode(stored) as Map<String, Object?>,
      );
    } catch (e) {
      errorLog('[$_logPrefix] Unreadable status for ${task.id}: $e');
      return null;
    }
  }

  /// Runs a task now, in the calling isolate, through the same lock and status
  /// bookkeeping a scheduled run uses. This is what a "Run now" button calls.
  static Future<BackgroundTaskResult> runNow(BackgroundTask task) =>
      _run(task, 'manual');

  /// The scheduled entry point. A false return asks WorkManager to retry with
  /// backoff ahead of the next interval.
  static Future<bool> executeHeadless(String taskId) async {
    final task = taskById(taskId);
    if (task == null) {
      // Retrying an id no build has a task for would loop forever.
      errorLog('[$_logPrefix] No task registered for "$taskId"');
      return true;
    }
    final result = await _run(task, 'scheduled');
    return result.outcome != BackgroundTaskOutcome.failed;
  }

  static Future<void> _apply(BackgroundTask task, Duration? interval) async {
    if (!isSupported) return;
    if (interval == null) {
      await Workmanager().cancelByUniqueName(task.id);
      return;
    }
    await Workmanager().registerPeriodicTask(
      task.id,
      task.id,
      frequency: interval < minimumInterval ? minimumInterval : interval,
      // `update` adopts a new frequency without restarting the period, so
      // re-applying an unchanged schedule on every launch - which is what
      // [init] does - cannot keep pushing a due run out of reach.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: task.requiresNetwork
            ? NetworkType.connected
            : NetworkType.notRequired,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  static Future<BackgroundTaskResult> _run(
    BackgroundTask task,
    String trigger,
  ) async {
    if (!await _acquireLock(task.id)) {
      debugLog('[$_logPrefix] ${task.id} is already running; skipping');
      return const BackgroundTaskResult.skipped('already running');
    }
    final started = DateTime.now();
    BackgroundTaskResult result;
    try {
      result = await task.run();
    } catch (e) {
      errorLog('[$_logPrefix] ${task.id} ($trigger) failed: $e');
      result = BackgroundTaskResult.failed('$e');
    } finally {
      await _releaseLock(task.id);
    }
    await _saveStatus(task, result);
    if (kDebugMode) {
      final seconds = DateTime.now().difference(started).inSeconds;
      debugLog(
        '[$_logPrefix] ${task.id} ($trigger) ${result.outcome.name} '
        'in ${seconds}s: ${result.detail}',
      );
    }
    return result;
  }

  /// The app and a scheduled run are separate isolates with their own database
  /// connections, so "already running" cannot be an in-memory flag.
  ///
  /// Read-then-write is not atomic, but the race window is milliseconds wide and
  /// losing it costs duplicated work rather than a corrupt store - tasks are
  /// expected to be idempotent regardless, since the platform can also retry
  /// one it stopped halfway.
  static Future<bool> _acquireLock(String taskId) async {
    final key = _key(taskId, _lockSuffix);
    final held = int.tryParse(
      await DatabaseService.instance.getSetting(_scope, key) ?? '',
    );
    if (held != null) {
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(held),
      );
      if (age < _lockTimeout) return false;
      errorLog(
        '[$_logPrefix] Lock for $taskId is ${age.inMinutes}min old; taking it',
      );
    }
    await DatabaseService.instance.setSetting(
      _scope,
      key,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
    return true;
  }

  static Future<void> _releaseLock(String taskId) =>
      DatabaseService.instance.deleteSetting(_scope, _key(taskId, _lockSuffix));

  static Future<void> _saveStatus(
    BackgroundTask task,
    BackgroundTaskResult result,
  ) async {
    final status = BackgroundTaskStatus(
      at: DateTime.now(),
      outcome: result.outcome,
      detail: result.detail,
    );
    await DatabaseService.instance.setSetting(
      _scope,
      _key(task.id, _statusSuffix),
      jsonEncode(status.toJson()),
    );
  }

  static String _key(String taskId, String suffix) => '${taskId}_$suffix';
}

/// The headless entry point WorkManager starts. Top level and marked for the
/// VM's entry-point table, or the tree shaker drops it from release builds.
///
/// Deliberately initializes nothing: services in this app open what they need on
/// first use, and `TempFileManager` in particular must stay out - its session
/// cleanup runs off an app lifecycle event that never arrives here, so every
/// background run would leave a session directory behind.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask(
    (taskId, _) => BackgroundTaskService.executeHeadless(taskId),
  );
}

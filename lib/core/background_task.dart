/// Deferrable work a tool wants run on a schedule while the app is closed.
///
/// Declared in the tool's `config.dart` through `backgroundTasks`; scheduled and
/// executed by `BackgroundTaskService`.
class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.run,
    required this.defaultInterval,
    this.requiresNetwork = false,
  });

  /// Unique across the app: it is both the platform's unique work name and the
  /// settings key the schedule and last result are stored under.
  final String id;

  /// Runs in the app's own isolate for a manual run, and in a headless engine
  /// for a scheduled one - no UI, no providers, no localizations. So it must
  /// reach state through services, and must never ask for a permission.
  final Future<BackgroundTaskResult> Function() run;

  /// Used until the user picks something else, so a task that ships enabled
  /// needs no first-run migration.
  final Duration defaultInterval;

  /// Whether the platform should hold a run back until there is a connection.
  /// Leave false for work with something useful to do offline.
  final bool requiresNetwork;
}

enum BackgroundTaskOutcome { done, skipped, failed }

/// What one run reports. [detail] is a short diagnostic line the settings UI
/// shows verbatim - the text around it is localized, this is not.
class BackgroundTaskResult {
  const BackgroundTaskResult.done([this.detail = ''])
    : outcome = BackgroundTaskOutcome.done;

  /// Nothing to do, or something else was already doing it. Not an error.
  const BackgroundTaskResult.skipped([this.detail = ''])
    : outcome = BackgroundTaskOutcome.skipped;

  /// Retried by the platform with backoff, ahead of the next interval.
  const BackgroundTaskResult.failed(this.detail)
    : outcome = BackgroundTaskOutcome.failed;

  final BackgroundTaskOutcome outcome;
  final String detail;
}

/// The last run of a task, persisted because nobody was watching it happen.
class BackgroundTaskStatus {
  const BackgroundTaskStatus({
    required this.at,
    required this.outcome,
    required this.detail,
  });

  final DateTime at;
  final BackgroundTaskOutcome outcome;
  final String detail;

  Map<String, Object?> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'outcome': outcome.name,
    'detail': detail,
  };

  static BackgroundTaskStatus? fromJson(Map<String, Object?> json) {
    final at = json['at'];
    if (at is! int) return null;
    return BackgroundTaskStatus(
      at: DateTime.fromMillisecondsSinceEpoch(at),
      outcome: BackgroundTaskOutcome.values.firstWhere(
        (outcome) => outcome.name == json['outcome'],
        orElse: () => BackgroundTaskOutcome.done,
      ),
      detail: json['detail'] as String? ?? '',
    );
  }
}

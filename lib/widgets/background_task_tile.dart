import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/theme/theme.dart';

/// Settings control for one [BackgroundTask]: how often it may run, what
/// happened the last time it did, and a way to run it right now.
///
/// Shared rather than per-tool because the schedule is the same idea everywhere -
/// only the wording around it is the tool's own.
class BackgroundTaskTile extends StatefulWidget {
  const BackgroundTaskTile({
    super.key,
    required this.task,
    required this.title,
    required this.description,
    this.icon = Icons.schedule_outlined,
    this.onRunFinished,
  });

  final BackgroundTask task;
  final String title;
  final String description;
  final IconData icon;

  /// Fired after a manual run, for pages that show data the run just changed.
  final VoidCallback? onRunFinished;

  @override
  State<BackgroundTaskTile> createState() => _BackgroundTaskTileState();
}

class _BackgroundTaskTileState extends State<BackgroundTaskTile> {
  Duration? _interval;
  BackgroundTaskStatus? _status;
  bool _loading = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final interval = await BackgroundTaskService.interval(widget.task);
    final status = await BackgroundTaskService.lastStatus(widget.task);
    if (!mounted) return;
    setState(() {
      _interval = interval;
      _status = status;
      _loading = false;
    });
  }

  Future<void> _select(Duration? interval) async {
    setState(() => _interval = interval);
    await BackgroundTaskService.setInterval(widget.task, interval);
  }

  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      await BackgroundTaskService.runNow(widget.task);
    } finally {
      if (mounted) setState(() => _running = false);
    }
    await _load();
    widget.onRunFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(widget.icon),
          title: Text(widget.title),
          subtitle: Text(widget.description),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                DropdownButton<int>(
                  value: _interval?.inMinutes ?? 0,
                  onChanged: (minutes) => _select(
                    minutes == null || minutes == 0
                        ? null
                        : Duration(minutes: minutes),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.backgroundTaskOff),
                    ),
                    for (final minutes in _choices())
                      DropdownMenuItem(
                        value: minutes,
                        child: Text(
                          _intervalLabel(l10n, Duration(minutes: minutes)),
                        ),
                      ),
                  ],
                ),
              TextButton.icon(
                onPressed: _running ? null : _runNow,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.backgroundTaskRunNow),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusLine(l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _statusColor(theme),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.backgroundTaskDozeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A stored interval no longer offered - an older build's step, a task that
  /// changed its own default - still has to be selectable, or the dropdown would
  /// have no item for its own value.
  List<int> _choices() {
    final minutes = {
      for (final choice in BackgroundTaskService.intervalChoices)
        choice.inMinutes,
      if (_interval != null) _interval!.inMinutes,
    }.toList()..sort();
    return minutes;
  }

  String _statusLine(AppLocalizations l10n) {
    final status = _status;
    if (status == null) return l10n.backgroundTaskNeverRun;
    final when = FormatHelper.dateTime(status.at);
    return status.detail.isEmpty
        ? when
        : l10n.backgroundTaskLastRun(when, status.detail);
  }

  Color? _statusColor(ThemeData theme) => switch (_status?.outcome) {
    BackgroundTaskOutcome.failed => AppTheme.statusRed,
    BackgroundTaskOutcome.skipped => AppTheme.statusAmber,
    _ => theme.textTheme.bodySmall?.color,
  };

  static String _intervalLabel(AppLocalizations l10n, Duration interval) {
    if (interval.inHours < 1) {
      return l10n.backgroundTaskEveryMinutes(interval.inMinutes);
    }
    if (interval.inHours >= 24) return l10n.backgroundTaskEveryDay;
    return l10n.backgroundTaskEveryHours(interval.inHours);
  }
}

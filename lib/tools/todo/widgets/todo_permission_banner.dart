import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/foreground_runtime_service.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';

/// Shown once a task has a reminder but Android would not deliver it on time.
class TodoPermissionBanner extends StatefulWidget {
  const TodoPermissionBanner({super.key});

  @override
  State<TodoPermissionBanner> createState() => _TodoPermissionBannerState();
}

class _TodoPermissionBannerState extends State<TodoPermissionBanner>
    with DisposeCleanup, WidgetsBindingObserver {
  TodoPermissionStatus _status = const TodoPermissionStatus();

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await TodoNative.permissionStatus();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid || _status.allGranted) {
      return const SizedBox.shrink();
    }
    final needsReminders = context.select<TodoState, bool>(
      (s) => s.tasks.any((t) => !t.completed && t.reminders.isNotEmpty),
    );
    final needsAlarms = context.select<TodoState, bool>(
      (s) =>
          s.tasks.any((t) => !t.completed && t.reminders.any((r) => r.alarm)),
    );
    final l10n = AppLocalizations.of(context);
    final actions = <Widget>[
      if (!_status.notifications && needsReminders)
        FilledButton.tonal(
          onPressed: () async {
            await ForegroundRuntimeService.requestNotificationPermission();
            await _refresh();
            if (!_status.notifications) {
              await TodoNative.openNotificationSettings();
            }
          },
          child: Text(l10n.todoPermissionNotifications),
        ),
      if (!_status.exactAlarms && needsReminders)
        FilledButton.tonal(
          onPressed: TodoNative.openExactAlarmSettings,
          child: Text(l10n.todoPermissionExact),
        ),
      if (!_status.fullScreen && needsAlarms)
        FilledButton.tonal(
          onPressed: TodoNative.openFullScreenSettings,
          child: Text(l10n.todoPermissionFullScreen),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.todoPermissionBanner,
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

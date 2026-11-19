import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/tools/todo/todo_background.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/widgets/background_task_tile.dart';

/// Reminder permissions, background refresh, swipe gestures and the
/// quick-add syntax.
class TodoSettingsSheet extends StatefulWidget {
  const TodoSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const TodoSettingsSheet(),
  );

  @override
  State<TodoSettingsSheet> createState() => _TodoSettingsSheetState();
}

class _TodoSettingsSheetState extends State<TodoSettingsSheet>
    with DisposeCleanup, WidgetsBindingObserver {
  TodoPermissionStatus? _status;

  @override
  void initState() {
    super.initState();
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = _status;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.todoSettings, style: theme.textTheme.titleLarge),
            ),
            if (Platform.isAndroid && status != null) ...[
              _PermissionTile(
                icon: Icons.notifications_outlined,
                title: l10n.todoPermissionNotifications,
                granted: status.notifications,
                onTap: TodoNative.openNotificationSettings,
              ),
              _PermissionTile(
                icon: Icons.schedule,
                title: l10n.todoPermissionExact,
                granted: status.exactAlarms,
                onTap: TodoNative.openExactAlarmSettings,
              ),
              _PermissionTile(
                icon: Icons.alarm,
                title: l10n.todoPermissionFullScreen,
                granted: status.fullScreen,
                onTap: TodoNative.openFullScreenSettings,
              ),
              const Divider(),
            ],
            if (BackgroundTaskService.isSupported)
              BackgroundTaskTile(
                task: TodoBackground.task,
                icon: Icons.sync_outlined,
                title: l10n.todoBackgroundTitle,
                description: l10n.todoBackgroundSubtitle,
              ),
            if (!Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.todoDesktopRemindersTitle),
                subtitle: Text(l10n.todoDesktopRemindersSubtitle),
              ),
            const Divider(),
            const _ReminderTimeTile(),
            const Divider(),
            const _SwipeSettings(),
            if (!Platform.isAndroid) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: Text(l10n.todoShortcutsTitle),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.todoShortcutsHelp),
                ),
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: Text(l10n.todoQuickAddHelpTitle),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.todoQuickAddHelp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        granted ? l10n.todoPermissionGranted : l10n.todoPermissionMissing,
      ),
      trailing: Icon(
        granted ? Icons.check_circle : Icons.error_outline,
        color: granted ? scheme.primary : scheme.error,
      ),
      onTap: onTap,
    );
  }
}

class _SwipeSettings extends StatelessWidget {
  const _SwipeSettings();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TodoState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.swipe_outlined),
          title: Text(l10n.todoSwipeTitle),
          subtitle: Text(l10n.todoSwipeHint),
        ),
        _SwipeActionTile(
          icon: Icons.east,
          title: l10n.todoSwipeRight,
          value: state.swipeStart,
          onChanged: (a) => state.setSwipeAction(start: true, action: a),
        ),
        _SwipeActionTile(
          icon: Icons.west,
          title: l10n.todoSwipeLeft,
          value: state.swipeEnd,
          onChanged: (a) => state.setSwipeAction(start: false, action: a),
        ),
      ],
    );
  }
}

class _SwipeActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final TodoSwipeAction value;
  final ValueChanged<TodoSwipeAction> onChanged;

  const _SwipeActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      TodoSwipeAction.none: l10n.todoSwipeNone,
      TodoSwipeAction.complete: l10n.todoSwipeComplete,
      TodoSwipeAction.delete: l10n.todoSwipeDelete,
      TodoSwipeAction.important: l10n.todoSwipeImportant,
      TodoSwipeAction.myDay: l10n.todoSwipeMyDay,
      TodoSwipeAction.tomorrow: l10n.todoSwipeTomorrow,
      TodoSwipeAction.nextWeek: l10n.todoSwipeNextWeek,
    };
    return PopupMenuButton<TodoSwipeAction>(
      tooltip: title,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in labels.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(labels[value]!),
      ),
    );
  }
}

class _ReminderTimeTile extends StatelessWidget {
  const _ReminderTimeTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TodoState>();
    final minutes = state.defaultReminderMinutes;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(l10n.todoDefaultReminderTime),
      subtitle: Text(l10n.todoDefaultReminderTimeHint),
      trailing: Text(time.format(context)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked == null) return;
        await state.setDefaultReminderMinutes(picked.hour * 60 + picked.minute);
      },
    );
  }
}

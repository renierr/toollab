import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_pickers.dart';
import 'package:tool_lab/tools/todo/widgets/todo_repeat_dialog.dart';

/// My Day, reminders, due date and repeat.
class TodoScheduleSection extends StatelessWidget {
  final TodoTask task;

  const TodoScheduleSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final state = context.read<TodoState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final inMyDay = task.isInMyDay(now);
    final active = theme.colorScheme.primary;

    return Column(
      children: [
        _ScheduleTile(
          icon: Icons.wb_sunny_outlined,
          label: inMyDay ? l10n.todoAddedToMyDay : l10n.todoAddToMyDay,
          color: inMyDay ? TodoColors.myDay : null,
          onTap: () => state.toggleMyDay(task),
          onClear: inMyDay ? () => state.toggleMyDay(task) : null,
        ),
        const Divider(height: 1, indent: 56),
        for (final reminder in task.reminders)
          _ScheduleTile(
            icon: reminder.alarm ? Icons.alarm : Icons.notifications_none,
            label: TodoFormat.dayTime(reminder.time, l10n, now: now),
            sublabel: reminder.alarm ? l10n.todoAlarm : l10n.todoReminder,
            color: reminder.time.isBefore(now) && task.recurrence == null
                ? theme.colorScheme.onSurfaceVariant
                : active,
            trailing: IconButton(
              tooltip: reminder.alarm
                  ? l10n.todoMakeReminder
                  : l10n.todoMakeAlarm,
              icon: Icon(
                reminder.alarm ? Icons.alarm_off : Icons.alarm_add,
                size: 20,
              ),
              onPressed: () => state.setReminders(task, [
                for (final r in task.reminders)
                  r == reminder ? TodoReminder(at: r.at, alarm: !r.alarm) : r,
              ]),
            ),
            onTap: () async {
              final picked = await TodoPickers.pickReminder(
                context,
                initial: reminder,
              );
              if (picked == null) return;
              await state.setReminders(task, [
                for (final r in task.reminders) r == reminder ? picked : r,
              ]);
            },
            onClear: () => state.setReminders(
              task,
              task.reminders.where((r) => r != reminder).toList(),
            ),
          ),
        _ScheduleTile(
          icon: Icons.add_alert_outlined,
          label: task.reminders.isEmpty
              ? l10n.todoRemindMe
              : l10n.todoAddReminder,
          onTap: () async {
            final picked = await TodoPickers.pickReminder(
              context,
              due: task.dueHasTime ? task.due : null,
            );
            if (picked == null) return;
            await state.setReminders(task, [...task.reminders, picked]);
          },
        ),
        const Divider(height: 1, indent: 56),
        _ScheduleTile(
          icon: Icons.event_outlined,
          label: task.dueAt == null
              ? l10n.todoAddDueDate
              : l10n.todoDueOn(TodoFormat.due(task, l10n, now: now)),
          color: task.dueAt == null
              ? null
              : task.isOverdue(now)
              ? TodoColors.overdue
              : active,
          onTap: () async {
            final picked = await TodoPickers.pickDue(
              context,
              initial: task.due,
              hasTime: task.dueHasTime,
            );
            if (picked == null) return;
            await state.setDue(task, picked.$1, hasTime: picked.$2);
          },
          onClear: task.dueAt == null ? null : () => state.setDue(task, null),
        ),
        const Divider(height: 1, indent: 56),
        _ScheduleTile(
          icon: Icons.repeat,
          label: task.recurrence == null
              ? l10n.todoRepeat
              : TodoFormat.recurrence(task.recurrence!, l10n),
          color: task.recurrence == null ? null : active,
          onTap: () async {
            final picked = await TodoRepeatDialog.pick(
              context,
              initial: task.recurrence,
              start: task.due ?? now,
            );
            if (picked == null) return;
            await state.setRecurrence(task, picked.recurrence);
          },
          onClear: task.recurrence == null
              ? null
              : () => state.setRecurrence(task, null),
        ),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Widget? trailing;

  const _ScheduleTile({
    required this.icon,
    required this.label,
    this.sublabel,
    this.color,
    required this.onTap,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(icon, color: color ?? muted),
      title: Text(label, style: TextStyle(color: color ?? muted)),
      subtitle: sublabel == null ? null : Text(sublabel!),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (onClear != null)
            IconButton(
              tooltip: l10n.todoRemove,
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

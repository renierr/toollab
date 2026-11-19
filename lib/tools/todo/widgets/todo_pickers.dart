import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';

/// Preset sheets for due dates and reminders, with a custom fallback.
class TodoPickers {
  TodoPickers._();

  /// Returns (date, hasTime), or null when cancelled.
  static Future<(DateTime, bool)?> pickDue(
    BuildContext context, {
    DateTime? initial,
    bool hasTime = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <(IconData, String, DateTime)>[
      (Icons.today, l10n.todoToday, today),
      (Icons.event, l10n.todoTomorrow, today.add(const Duration(days: 1))),
      (
        Icons.date_range,
        l10n.todoNextWeek,
        today.add(Duration(days: 8 - today.weekday)),
      ),
    ];
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PresetSheet(
        title: l10n.todoDue,
        presets: [
          for (final p in presets)
            _Preset(
              p.$1,
              p.$2,
              TodoFormat.weekdayShort(p.$3.weekday, l10n),
              p.$3,
            ),
        ],
        customLabel: l10n.todoPickDate,
      ),
    );
    if (choice is DateTime) return (choice, false);
    if (choice != _custom || !context.mounted) return null;

    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 20),
    );
    if (date == null || !context.mounted) return null;
    final withTime = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.todoAddTimeQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.todoAllDay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.todoSetTime),
          ),
        ],
      ),
    );
    if (withTime != true || !context.mounted) return (date, false);
    final time = await showTimePicker(
      context: context,
      initialTime: hasTime && initial != null
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return (date, false);
    return (
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
      true,
    );
  }

  static Future<TodoReminder?> pickReminder(
    BuildContext context, {
    TodoReminder? initial,
    DateTime? due,
  }) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final laterToday = DateTime(now.year, now.month, now.day, now.hour + 3);
    final presets = <_Preset>[
      if (due != null && due.isAfter(now)) ...[
        _Preset(
          Icons.schedule,
          l10n.todoAtDueTime,
          TodoFormat.dayTime(due, l10n),
          due,
        ),
        _Preset(
          Icons.timer_outlined,
          l10n.todoMinutesBefore(15),
          TodoFormat.time(due.subtract(const Duration(minutes: 15)), l10n),
          due.subtract(const Duration(minutes: 15)),
        ),
        _Preset(
          Icons.timer_outlined,
          l10n.todoHourBefore,
          TodoFormat.time(due.subtract(const Duration(hours: 1)), l10n),
          due.subtract(const Duration(hours: 1)),
        ),
      ],
      if (laterToday.day == now.day)
        _Preset(
          Icons.update,
          l10n.todoLaterToday,
          TodoFormat.time(laterToday, l10n),
          laterToday,
        ),
      _Preset(
        Icons.event,
        l10n.todoTomorrow,
        TodoFormat.time(today.add(const Duration(days: 1, hours: 9)), l10n),
        today.add(const Duration(days: 1, hours: 9)),
      ),
      _Preset(
        Icons.date_range,
        l10n.todoNextWeek,
        TodoFormat.dayTime(
          today.add(Duration(days: 8 - today.weekday, hours: 9)),
          l10n,
        ),
        today.add(Duration(days: 8 - today.weekday, hours: 9)),
      ),
    ];
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PresetSheet(
        title: l10n.todoRemindMe,
        presets: presets,
        customLabel: l10n.todoPickDateTime,
        alarmToggle: initial?.alarm ?? false,
      ),
    );
    if (choice is _ReminderChoice) {
      return TodoReminder(
        at: choice.at.millisecondsSinceEpoch,
        alarm: choice.alarm,
      );
    }
    if (choice is! _CustomChoice || !context.mounted) return null;

    final start = initial?.time ?? today.add(const Duration(days: 1, hours: 9));
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(today) ? today : start,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: DateTime(today.year + 20),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null) return null;
    return TodoReminder(
      at: DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).millisecondsSinceEpoch,
      alarm: choice.alarm,
    );
  }
}

const Object _custom = _CustomChoice(false);

class _CustomChoice {
  final bool alarm;

  const _CustomChoice(this.alarm);

  @override
  bool operator ==(Object other) => other is _CustomChoice;

  @override
  int get hashCode => 0;
}

class _ReminderChoice {
  final DateTime at;
  final bool alarm;

  const _ReminderChoice(this.at, this.alarm);
}

class _Preset {
  final IconData icon;
  final String label;
  final String detail;
  final DateTime value;

  const _Preset(this.icon, this.label, this.detail, this.value);
}

/// Without [alarmToggle] the sheet pops the plain [DateTime]; with it, a
/// reminder choice carrying the alarm flag.
class _PresetSheet extends StatefulWidget {
  final String title;
  final List<_Preset> presets;
  final String customLabel;
  final bool? alarmToggle;

  const _PresetSheet({
    required this.title,
    required this.presets,
    required this.customLabel,
    this.alarmToggle,
  });

  @override
  State<_PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends State<_PresetSheet> {
  late bool _alarm = widget.alarmToggle ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reminder = widget.alarmToggle != null;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            for (final p in widget.presets)
              ListTile(
                leading: Icon(p.icon),
                title: Text(p.label),
                trailing: Text(
                  p.detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  reminder ? _ReminderChoice(p.value, _alarm) : p.value,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(widget.customLabel),
              onTap: () => Navigator.pop(context, _CustomChoice(_alarm)),
            ),
            if (reminder) ...[
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.alarm),
                title: Text(l10n.todoAlarm),
                subtitle: Text(l10n.todoAlarmHint),
                value: _alarm,
                onChanged: (v) => setState(() => _alarm = v),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

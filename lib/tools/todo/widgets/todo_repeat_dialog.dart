import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class TodoRepeatChoice {
  final TodoRecurrence? recurrence;

  const TodoRepeatChoice(this.recurrence);
}

/// Preset sheet, then a full editor for "custom".
class TodoRepeatDialog extends StatefulWidget {
  final TodoRecurrence initial;
  final DateTime start;

  const TodoRepeatDialog({
    super.key,
    required this.initial,
    required this.start,
  });

  static Future<TodoRepeatChoice?> pick(
    BuildContext context, {
    TodoRecurrence? initial,
    required DateTime start,
  }) async {
    final l10n = AppLocalizations.of(context);
    final presets = <(IconData, TodoRecurrence)>[
      (Icons.today, TodoRecurrence.daily),
      (Icons.work_outline, TodoRecurrence.weekdaysOnly),
      (Icons.view_week_outlined, TodoRecurrence.weekly),
      (Icons.calendar_month_outlined, TodoRecurrence.monthly),
      (Icons.cake_outlined, TodoRecurrence.yearly),
    ];
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in presets)
                ListTile(
                  leading: Icon(p.$1),
                  title: Text(TodoFormat.recurrence(p.$2, l10n)),
                  selected: initial == p.$2,
                  onTap: () => Navigator.pop(context, p.$2),
                ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(l10n.todoRepeatCustom),
                onTap: () => Navigator.pop(context, 'custom'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice is TodoRecurrence) return TodoRepeatChoice(choice);
    if (choice != 'custom' || !context.mounted) return null;
    final custom = await showDialog<TodoRecurrence>(
      context: context,
      builder: (_) => TodoRepeatDialog(
        initial: initial ?? TodoRecurrence.weekly,
        start: start,
      ),
    );
    return custom == null ? null : TodoRepeatChoice(custom);
  }

  @override
  State<TodoRepeatDialog> createState() => _TodoRepeatDialogState();
}

class _TodoRepeatDialogState extends State<TodoRepeatDialog> {
  late TodoRecurrence _rule = widget.initial;
  late final TextEditingController _interval = TextEditingController(
    text: '${widget.initial.interval}',
  );

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  int get _nthOfStart {
    final day = widget.start.day;
    final last = DateTime(widget.start.year, widget.start.month + 1, 0).day;
    if (day + 7 > last) return -1;
    return ((day - 1) ~/ 7) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unitLabels = {
      RecurrenceFreq.daily: l10n.todoUnitDays,
      RecurrenceFreq.weekly: l10n.todoUnitWeeks,
      RecurrenceFreq.monthly: l10n.todoUnitMonths,
      RecurrenceFreq.yearly: l10n.todoUnitYears,
    };
    return ResponsiveAlertDialog(
      title: Text(l10n.todoRepeatCustom),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.todoRepeatEvery),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      setState(() => _rule = _rule.copyWith(interval: n));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<RecurrenceFreq>(
                  isExpanded: true,
                  value: _rule.freq,
                  items: [
                    for (final f in RecurrenceFreq.values)
                      DropdownMenuItem(value: f, child: Text(unitLabels[f]!)),
                  ],
                  onChanged: (f) => setState(
                    () => _rule = TodoRecurrence(
                      freq: f!,
                      interval: _rule.interval,
                      until: _rule.until,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_rule.freq == RecurrenceFreq.weekly)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(TodoFormat.weekdayShort(d, l10n)),
                    selected: _rule.weekdays.contains(d),
                    onSelected: (on) => setState(() {
                      final days = {..._rule.weekdays};
                      on ? days.add(d) : days.remove(d);
                      _rule = _rule.copyWith(weekdays: days);
                    }),
                  ),
              ],
            ),
          if (_rule.freq == RecurrenceFreq.monthly)
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.todoMonthlyOnDay(widget.start.day)),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    '${TodoFormat.nthLabel(_nthOfStart, l10n)} ${TodoFormat.weekdayLong(widget.start.weekday, l10n)}',
                  ),
                ),
              ],
              selected: {_rule.monthlyNth != null},
              onSelectionChanged: (s) => setState(
                () => _rule = s.first
                    ? _rule.copyWith(
                        monthlyNth: () => _nthOfStart,
                        weekdays: {widget.start.weekday},
                      )
                    : _rule.copyWith(monthlyNth: () => null, weekdays: {}),
              ),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(
              _rule.until == null
                  ? l10n.todoRepeatForever
                  : l10n.todoRepeatUntil(
                      DateFormat.yMMMd(l10n.localeName).format(_rule.until!),
                    ),
            ),
            trailing: _rule.until == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(
                      () => _rule = _rule.copyWith(until: () => null),
                    ),
                  ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate:
                    _rule.until ?? widget.start.add(const Duration(days: 30)),
                firstDate: widget.start,
                lastDate: DateTime(widget.start.year + 30),
              );
              if (date != null) {
                setState(() => _rule = _rule.copyWith(until: () => date));
              }
            },
          ),
          Text(
            TodoFormat.recurrence(_rule, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _rule),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

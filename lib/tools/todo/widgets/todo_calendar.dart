import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_undo.dart';

/// Month grid of [tasks] by due day, with the selected day's tasks below.
/// Long-press a task and drop it on a day to move it there.
class TodoCalendar extends StatefulWidget {
  final List<TodoTask> tasks;
  final Widget Function(TodoTask task) tileBuilder;

  const TodoCalendar({
    super.key,
    required this.tasks,
    required this.tileBuilder,
  });

  @override
  State<TodoCalendar> createState() => _TodoCalendarState();
}

class _TodoCalendarState extends State<TodoCalendar> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selected = _day(now);
      _month = DateTime(now.year, now.month);
    });
  }

  Future<void> _drop(TodoTask task, DateTime day) async {
    if (task.due != null && _day(task.due!) == day) return;
    final l10n = AppLocalizations.of(context);
    final notifier = TodoUndoNotifier.of(context);
    final undo = await context.read<TodoState>().moveDue([task], day);
    notifier.show(
      l10n.todoMovedToDaySnack(task.title, TodoFormat.day(day, l10n)),
      undo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final byDay = <DateTime, List<TodoTask>>{};
    for (final t in widget.tasks) {
      if (t.due == null) continue;
      byDay.putIfAbsent(_day(t.due!), () => []).add(t);
    }
    final selectedTasks = byDay[_selected] ?? const <TodoTask>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.todoPreviousMonth,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _goToday,
                  child: Text(
                    DateFormat.yMMMM(l10n.localeName).format(_month),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.todoNextMonth,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _MonthGrid(
            month: _month,
            selected: _selected,
            byDay: byDay,
            onSelect: (day) => setState(() {
              _selected = day;
              if (day.month != _month.month) {
                _month = DateTime(day.year, day.month);
              }
            }),
            onDrop: _drop,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            TodoFormat.day(_selected, l10n),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (selectedTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              l10n.todoCalendarEmptyDay,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          for (final task in selectedTasks)
            _DraggableTask(task: task, child: widget.tileBuilder(task)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              l10n.todoCalendarDragHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final Map<DateTime, List<TodoTask>> byDay;
  final ValueChanged<DateTime> onSelect;
  final void Function(TodoTask task, DateTime day) onDrop;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.onSelect,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final start = DateTime(first.year, first.month, 2 - first.weekday);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((first.weekday - 1 + daysInMonth) / 7).ceil();
    final days = [
      for (var i = 0; i < weeks * 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (var d = 1; d <= 7; d++)
              Expanded(
                child: Center(
                  child: Text(
                    TodoFormat.weekdayShort(d, l10n),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (final day in days.sublist(w * 7, w * 7 + 7))
                Expanded(
                  child: _DayCell(
                    day: day,
                    inMonth: day.month == month.month,
                    selected: day == selected,
                    tasks: byDay[day] ?? const [],
                    onSelect: onSelect,
                    onDrop: onDrop,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool selected;
  final List<TodoTask> tasks;
  final ValueChanged<DateTime> onSelect;
  final void Function(TodoTask task, DateTime day) onDrop;

  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.tasks,
    required this.onSelect,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = context.read<TodoState>();
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final overdue = tasks.any((t) => t.isOverdue(now));
    return DragTarget<TodoTask>(
      onAcceptWithDetails: (details) => onDrop(details.data, day),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: hovering
                ? scheme.primaryContainer
                : selected
                ? scheme.secondaryContainer
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: isToday
                  ? BorderSide(color: scheme.primary, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(day),
              child: SizedBox(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: inMonth
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: isToday ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final t in tasks.take(3))
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: overdue
                                    ? TodoColors.overdue
                                    : Color(
                                        state.listById(t.listId)?.color ??
                                            TodoColors.planned.toARGB32(),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DraggableTask extends StatelessWidget {
  final TodoTask task;
  final Widget child;

  const _DraggableTask({required this.task, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LongPressDraggable<TodoTask>(
      data: task,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

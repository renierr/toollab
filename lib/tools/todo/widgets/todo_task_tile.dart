import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/widgets/todo_check_circle.dart';
import 'package:tool_lab/tools/todo/widgets/todo_undo.dart';

class TodoTaskTile extends StatelessWidget {
  final TodoTask task;
  final bool showList;
  final bool selected;
  final VoidCallback onOpen;
  final Widget? dragHandle;

  const TodoTaskTile({
    super.key,
    required this.task,
    required this.showList,
    required this.selected,
    required this.onOpen,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<TodoState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = state.listById(task.listId);
    final listColor = Color(list?.color ?? 0xFF4FC3F7);
    final overdue = !task.completed && task.isOverdue(DateTime.now());

    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : overdue
            ? Color.alphaBlend(
                TodoColors.overdue.withValues(alpha: 0.12),
                scheme.surfaceContainerHigh,
              )
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: overdue
                ? const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: TodoColors.overdue, width: 4),
                    ),
                  )
                : null,
            padding: EdgeInsets.fromLTRB(overdue ? 0 : 4, 6, 4, 6),
            child: Row(
              children: [
                TodoCheckCircle(
                  checked: task.completed,
                  color: listColor,
                  onTap: () async {
                    final notifier = TodoUndoNotifier.of(context);
                    final undo = await state.toggleCompleted(task);
                    if (!task.completed) {
                      notifier.show(l10n.todoCompletedSnack(task.title), undo);
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.completed
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                        _TaskMeta(
                          task: task,
                          listName: showList && list != null
                              ? todoListName(list, l10n)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.todoImportant,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      task.important ? Icons.star : Icons.star_border,
                      key: ValueKey(task.important),
                      color: task.important
                          ? TodoColors.star
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  onPressed: () => state.toggleImportant(task),
                ),
                ?dragHandle,
              ],
            ),
          ),
        ),
      ),
    );
    return _SwipeActions(
      task: task,
      start: state.swipeStart,
      end: state.swipeEnd,
      child: card,
    );
  }
}

/// Swipe actions from settings. Drags starting at the tile edges are
/// swallowed so the system back gesture does not complete or delete a task.
class _SwipeActions extends StatelessWidget {
  final TodoTask task;
  final TodoSwipeAction start;
  final TodoSwipeAction end;
  final Widget child;

  const _SwipeActions({
    required this.task,
    required this.start,
    required this.end,
    required this.child,
  });

  static const double _edgeMargin = 32;

  Future<bool> _run(BuildContext context, TodoSwipeAction action) async {
    final state = context.read<TodoState>();
    final l10n = AppLocalizations.of(context);
    final notifier = TodoUndoNotifier.of(context);
    switch (action) {
      case TodoSwipeAction.none:
        return false;
      case TodoSwipeAction.complete:
        final undo = await state.toggleCompleted(task);
        if (!task.completed) {
          notifier.show(l10n.todoCompletedSnack(task.title), undo);
        }
        return false;
      case TodoSwipeAction.delete:
        final undo = await state.deleteTask(task);
        notifier.show(l10n.todoDeletedSnack(task.title), undo);
        return true;
      case TodoSwipeAction.important:
        await state.toggleImportant(task);
        return false;
      case TodoSwipeAction.myDay:
        await state.toggleMyDay(task);
        return false;
      case TodoSwipeAction.tomorrow:
        final undo = await state.moveDue([task], TodoState.tomorrow);
        notifier.show(l10n.todoMovedTomorrowSnack(task.title), undo);
        return false;
      case TodoSwipeAction.nextWeek:
        final undo = await state.moveDue([task], TodoState.nextMonday);
        notifier.show(l10n.todoMovedNextWeekSnack(task.title), undo);
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStart = start != TodoSwipeAction.none;
    final hasEnd = end != TodoSwipeAction.none;
    if (!hasStart && !hasEnd) return child;
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final left = math.max(_edgeMargin, insets.left + 16);
    final right = math.max(_edgeMargin, insets.right + 16);
    final startBackground = _SwipeBackground(
      action: start,
      task: task,
      alignment: AlignmentDirectional.centerStart,
    );
    final endBackground = _SwipeBackground(
      action: end,
      task: task,
      alignment: AlignmentDirectional.centerEnd,
    );
    return Stack(
      children: [
        Dismissible(
          key: ValueKey('todo-dismiss-${task.shortId}'),
          direction: hasStart && hasEnd
              ? DismissDirection.horizontal
              : hasStart
              ? DismissDirection.startToEnd
              : DismissDirection.endToStart,
          background: hasStart ? startBackground : endBackground,
          secondaryBackground: hasStart && hasEnd ? endBackground : null,
          confirmDismiss: (direction) => _run(
            context,
            direction == DismissDirection.startToEnd ? start : end,
          ),
          child: child,
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: left,
          child: const _EdgeGuard(),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: right,
          child: const _EdgeGuard(),
        ),
      ],
    );
  }
}

/// Wins the horizontal drag arena over [Dismissible]; taps still pass through.
class _EdgeGuard extends StatelessWidget {
  const _EdgeGuard();

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) {},
  );
}

class _TaskMeta extends StatelessWidget {
  final TodoTask task;
  final String? listName;

  const _TaskMeta({required this.task, this.listName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final now = DateTime.now();
    final style = theme.textTheme.bodySmall?.copyWith(color: muted);
    final attachments = context
        .read<TodoState>()
        .attachmentsFor(task.shortId)
        .length;

    final items = <Widget>[
      if (task.isInMyDay(now) && !task.completed)
        _MetaItem(icon: Icons.wb_sunny_outlined, label: l10n.todoMyDay),
      if (listName != null) _MetaItem(label: listName!),
      if (task.steps.isNotEmpty)
        _MetaItem(
          icon: Icons.checklist,
          label: l10n.todoStepsProgress(task.stepsDone, task.steps.length),
        ),
      if (task.dueAt != null && !task.completed && task.isOverdue(now))
        _MetaItem(
          icon: Icons.error_outline,
          label:
              '${l10n.todoGroupOverdue} · ${TodoFormat.due(task, l10n, now: now)}',
          color: TodoColors.overdue,
          bold: true,
        )
      else if (task.dueAt != null)
        _MetaItem(
          icon: Icons.event_outlined,
          label: TodoFormat.due(task, l10n, now: now),
          color: _isToday(task.due!, now) ? theme.colorScheme.primary : null,
        ),
      if (!task.completed && task.isDeferred(now))
        _MetaItem(
          icon: Icons.visibility_off_outlined,
          label: l10n.todoStartsMeta(
            TodoFormat.day(task.start!, l10n, now: now),
          ),
        ),
      if (task.recurrence != null) const _MetaItem(icon: Icons.repeat),
      if (task.reminders.isNotEmpty)
        _MetaItem(
          icon: task.reminders.any((r) => r.alarm)
              ? Icons.alarm
              : Icons.notifications_none,
        ),
      if (attachments > 0)
        _MetaItem(icon: Icons.attach_file, label: '$attachments'),
      if (task.note.trim().isNotEmpty) const _MetaItem(icon: Icons.notes),
      for (final tag in task.tags) _MetaItem(label: '#$tag'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: DefaultTextStyle.merge(
        style: style,
        child: IconTheme.merge(
          data: IconThemeData(size: 14, color: muted),
          child: Wrap(spacing: 10, runSpacing: 2, children: items),
        ),
      ),
    );
  }

  static bool _isToday(DateTime d, DateTime now) =>
      d.year == now.year && d.month == now.month && d.day == now.day;
}

class _MetaItem extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final Color? color;
  final bool bold;

  const _MetaItem({this.icon, this.label, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, color: color),
        if (icon != null && label != null) const SizedBox(width: 3),
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
      ],
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final TodoSwipeAction action;
  final TodoTask task;
  final AlignmentGeometry alignment;

  const _SwipeBackground({
    required this.action,
    required this.task,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (action) {
      TodoSwipeAction.complete => (
        TodoColors.completed,
        task.completed ? Icons.undo : Icons.check,
      ),
      TodoSwipeAction.delete => (scheme.error, Icons.delete_outline),
      TodoSwipeAction.important => (
        TodoColors.star,
        task.important ? Icons.star_border : Icons.star,
      ),
      TodoSwipeAction.myDay => (
        TodoColors.myDay,
        task.isInMyDay(DateTime.now())
            ? Icons.wb_sunny_outlined
            : Icons.wb_sunny,
      ),
      TodoSwipeAction.tomorrow => (TodoColors.planned, Icons.redo),
      TodoSwipeAction.nextWeek => (TodoColors.planned, Icons.date_range),
      TodoSwipeAction.none => (Colors.transparent, null),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: icon == null ? null : Icon(icon, color: scheme.surface),
    );
  }
}

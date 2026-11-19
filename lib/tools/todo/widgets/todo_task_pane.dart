import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_colors.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';
import 'package:tool_lab/tools/todo/widgets/todo_permission_banner.dart';
import 'package:tool_lab/tools/todo/widgets/todo_quick_add_bar.dart';
import 'package:tool_lab/tools/todo/widgets/todo_task_tile.dart';
import 'package:tool_lab/tools/todo/widgets/todo_undo.dart';
import 'package:tool_lab/widgets/readable_width.dart';

/// Header, task list (grouped, reorderable or plain) and the quick-add bar.
class TodoTaskPane extends StatelessWidget {
  final ValueChanged<TodoTask> onOpenTask;
  final FocusNode quickAddFocus;
  final VoidCallback? onOpenLists;

  const TodoTaskPane({
    super.key,
    required this.onOpenTask,
    required this.quickAddFocus,
    this.onOpenLists,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodoState>();
    final l10n = AppLocalizations.of(context);
    final view = state.view;
    final searching = state.query.trim().isNotEmpty;
    final open = state.openTasks(view);
    final completed = state.completedTasks(view);
    final accent = view.smart != null
        ? TodoColors.smart(view.smart!)
        : Color(state.colorFor(view));
    final showList = view.kind != TodoViewKind.list || searching;
    final selectedId = state.selectedTask?.shortId;
    final manual =
        !searching &&
        state.sortFor(view) == TodoSort.manual &&
        view.smart != TodoSmartList.completed;
    final grouped = !searching && view.smart == TodoSmartList.planned;

    Widget tile(TodoTask task, {int? index}) => TodoTaskTile(
      key: ValueKey(task.shortId),
      task: task,
      showList: showList,
      selected: task.shortId == selectedId,
      onOpen: () => onOpenTask(task),
      dragHandle: index == null
          ? null
          : ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.drag_indicator, size: 20),
              ),
            ),
    );

    return Column(
      children: [
        const TodoPermissionBanner(),
        Expanded(
          child: ReadableScrollPadding(
            padding: const EdgeInsets.only(bottom: 16),
            builder: (context, padding) => CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: padding.left,
                    right: padding.right,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _PaneHeader(
                      title: searching
                          ? l10n.todoSearchResults
                          : state
                                .viewTitle(
                                  view,
                                  (s) => TodoFormat.smartName(s, l10n),
                                )
                                .ifEmpty(() => _defaultName(state, view, l10n)),
                      subtitle: view.smart == TodoSmartList.myDay && !searching
                          ? DateFormat.MMMMEEEEd(
                              l10n.localeName,
                            ).format(DateTime.now())
                          : null,
                      color: accent,
                      onTap: onOpenLists,
                    ),
                  ),
                ),
                if (open.isEmpty && completed.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(view: view, searching: searching),
                  )
                else if (grouped)
                  for (final group in _plannedGroups(open, l10n)) ...[
                    _SectionHeader(
                      label: group.$1,
                      padding: padding,
                      action: group.$1 == l10n.todoGroupOverdue
                          ? _MoveOverdueButton(tasks: group.$2)
                          : null,
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: padding.left,
                        right: padding.right,
                      ),
                      sliver: SliverList.list(
                        children: [for (final t in group.$2) tile(t)],
                      ),
                    ),
                  ]
                else if (manual)
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: padding.left,
                      right: padding.right,
                    ),
                    sliver: SliverReorderableList(
                      itemCount: open.length,
                      itemBuilder: (context, i) => tile(open[i], index: i),
                      onReorderItem: (from, to) =>
                          state.reorder(open, from, to),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: padding.left,
                      right: padding.right,
                    ),
                    sliver: SliverList.builder(
                      itemCount: open.length,
                      itemBuilder: (context, i) => tile(open[i]),
                    ),
                  ),
                if (completed.isNotEmpty &&
                    view.smart != TodoSmartList.completed) ...[
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: padding.left,
                      right: padding.right,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _CompletedHeader(
                        count: completed.length,
                        expanded: state.completedExpanded(view) || searching,
                        onTap: () => state.toggleCompletedExpanded(view),
                      ),
                    ),
                  ),
                  if (state.completedExpanded(view) || searching)
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: padding.left,
                        right: padding.right,
                      ),
                      sliver: SliverList.builder(
                        itemCount: completed.length,
                        itemBuilder: (context, i) => tile(completed[i]),
                      ),
                    ),
                ] else if (view.smart == TodoSmartList.completed)
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: padding.left,
                      right: padding.right,
                    ),
                    sliver: SliverList.builder(
                      itemCount: completed.length,
                      itemBuilder: (context, i) => tile(completed[i]),
                    ),
                  ),
                SliverPadding(padding: EdgeInsets.only(bottom: padding.bottom)),
              ],
            ),
          ),
        ),
        if (view.smart != TodoSmartList.completed)
          ReadableWidth(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: TodoQuickAddBar(
                  accent: accent,
                  focusNode: quickAddFocus,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _defaultName(
    TodoState state,
    TodoView view,
    AppLocalizations l10n,
  ) {
    final list = state.listById(view.id);
    return list == null ? '' : todoListName(list, l10n);
  }

  static List<(String, List<TodoTask>)> _plannedGroups(
    List<TodoTask> tasks,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(Duration(days: 8 - today.weekday));
    final groups = <String, List<TodoTask>>{
      l10n.todoGroupOverdue: [],
      l10n.todoToday: [],
      l10n.todoTomorrow: [],
      l10n.todoGroupThisWeek: [],
      l10n.todoGroupLater: [],
    };
    for (final t in tasks) {
      final d = t.due!;
      final day = DateTime(d.year, d.month, d.day);
      final key = t.isOverdue(now)
          ? l10n.todoGroupOverdue
          : day == today
          ? l10n.todoToday
          : day == tomorrow
          ? l10n.todoTomorrow
          : day.isBefore(weekEnd)
          ? l10n.todoGroupThisWeek
          : l10n.todoGroupLater;
      groups[key]!.add(t);
    }
    return [
      for (final e in groups.entries)
        if (e.value.isNotEmpty) (e.key, e.value),
    ];
  }
}

extension on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}

class _PaneHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _PaneHeader({
    required this.title,
    this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = Text(
      title,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onTap == null)
                titleText
              else
                Row(
                  children: [
                    Flexible(child: titleText),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, color: color, size: 28),
                  ],
                ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _CompletedHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onTap,
          icon: AnimatedRotation(
            turns: expanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.chevron_right),
          ),
          label: Text(
            AppLocalizations.of(context).todoCompletedCount(count),
            style: theme.textTheme.titleSmall,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TodoView view;
  final bool searching;

  const _EmptyState({required this.view, required this.searching});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, text) = searching
        ? (Icons.search_off, l10n.todoEmptySearch)
        : switch (view.smart) {
            TodoSmartList.myDay => (
              Icons.wb_sunny_outlined,
              l10n.todoEmptyMyDay,
            ),
            TodoSmartList.important => (
              Icons.star_outline,
              l10n.todoEmptyImportant,
            ),
            TodoSmartList.planned => (
              Icons.event_outlined,
              l10n.todoEmptyPlanned,
            ),
            TodoSmartList.completed => (
              Icons.check_circle_outline,
              l10n.todoEmptyCompleted,
            ),
            _ => (Icons.task_alt, l10n.todoEmptyList),
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final EdgeInsets padding;
  final Widget? action;

  const _SectionHeader({
    required this.label,
    required this.padding,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        padding.left + 20,
        action == null ? 14 : 4,
        padding.right + (action == null ? 20 : 8),
        action == null ? 6 : 0,
      ),
      sliver: SliverToBoxAdapter(
        child: action == null
            ? text
            : Row(
                children: [
                  Expanded(child: text),
                  action!,
                ],
              ),
      ),
    );
  }
}

class _MoveOverdueButton extends StatelessWidget {
  final List<TodoTask> tasks;

  const _MoveOverdueButton({required this.tasks});

  Future<void> _move(BuildContext context, DateTime day) async {
    final l10n = AppLocalizations.of(context);
    final notifier = TodoUndoNotifier.of(context);
    final undo = await context.read<TodoState>().moveDue(tasks, day);
    notifier.show(l10n.todoMovedOverdueSnack(tasks.length), undo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    return PopupMenuButton<DateTime>(
      tooltip: l10n.todoMoveOverdue,
      onSelected: (day) => _move(context, day),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: DateTime(now.year, now.month, now.day),
          child: Text(l10n.todoToday),
        ),
        PopupMenuItem(
          value: TodoState.tomorrow,
          child: Text(l10n.todoTomorrow),
        ),
        PopupMenuItem(
          value: TodoState.nextMonday,
          child: Text(l10n.todoNextWeek),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_repeat, size: 18, color: TodoColors.planned),
            const SizedBox(width: 4),
            Text(
              l10n.todoMoveOverdue,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: TodoColors.planned),
            ),
          ],
        ),
      ),
    );
  }
}

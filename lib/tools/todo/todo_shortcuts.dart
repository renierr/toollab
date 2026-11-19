import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';
import 'package:tool_lab/tools/todo/widgets/todo_undo.dart';

/// Page-wide keys, handled globally so they work without a focused widget.
/// Plain keys only act while no widget holds focus: every keyboard handler
/// sees the event, so a focused field or button would react as well.
class TodoShortcuts {
  final BuildContext Function() context;
  final VoidCallback onQuickAdd;
  final VoidCallback onToggleSearch;
  final bool Function() isSearching;
  final ValueChanged<TodoTask> onOpenTask;

  TodoShortcuts({
    required this.context,
    required this.onQuickAdd,
    required this.onToggleSearch,
    required this.isSearching,
    required this.onOpenTask,
  });

  void attach() => HardwareKeyboard.instance.addHandler(_handle);

  void detach() => HardwareKeyboard.instance.removeHandler(_handle);

  static bool get _widgetFocused {
    final focus = FocusManager.instance.primaryFocus;
    return focus != null && focus is! FocusScopeNode;
  }

  bool _handle(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final ctx = context();
    if (!ctx.mounted || !(ModalRoute.of(ctx)?.isCurrent ?? false)) return false;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final repeat = event is KeyRepeatEvent;

    if (ctrl && !repeat) {
      if (key == LogicalKeyboardKey.keyN) {
        onQuickAdd();
        return true;
      }
      if (key == LogicalKeyboardKey.keyF) {
        onToggleSearch();
        return true;
      }
      return false;
    }
    if (_widgetFocused || keyboard.isAltPressed) return false;

    final state = ctx.read<TodoState>();
    if (key == LogicalKeyboardKey.arrowDown) return _step(state, 1);
    if (key == LogicalKeyboardKey.arrowUp) return _step(state, -1);
    if (repeat) return false;
    if (key == LogicalKeyboardKey.escape) {
      if (state.selectedTask != null) {
        state.selectTask(null);
        return true;
      }
      if (isSearching()) {
        onToggleSearch();
        return true;
      }
      return false;
    }

    final task = state.selectedTask;
    if (task == null) return false;
    final l10n = AppLocalizations.of(ctx);
    final notifier = TodoUndoNotifier.of(ctx);
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      onOpenTask(task);
    } else if (key == LogicalKeyboardKey.space) {
      state.toggleCompleted(task).then((undo) {
        if (!task.completed) {
          notifier.show(l10n.todoCompletedSnack(task.title), undo);
        }
      });
    } else if (key == LogicalKeyboardKey.delete) {
      _selectNeighbour(state, task);
      state
          .deleteTask(task)
          .then(
            (undo) => notifier.show(l10n.todoDeletedSnack(task.title), undo),
          );
    } else if (key == LogicalKeyboardKey.keyI) {
      state.toggleImportant(task);
    } else if (key == LogicalKeyboardKey.keyM) {
      state.toggleMyDay(task);
    } else if (key == LogicalKeyboardKey.keyT) {
      state
          .moveDue([task], TodoState.tomorrow)
          .then(
            (undo) =>
                notifier.show(l10n.todoMovedTomorrowSnack(task.title), undo),
          );
    } else {
      return false;
    }
    return true;
  }

  static List<TodoTask> _visible(TodoState state) => [
    ...state.openTasks(state.view),
    if (state.completedExpanded(state.view) ||
        state.view.smart == TodoSmartList.completed ||
        state.query.trim().isNotEmpty)
      ...state.completedTasks(state.view),
  ];

  bool _step(TodoState state, int delta) {
    final tasks = _visible(state);
    if (tasks.isEmpty) return false;
    final current = tasks.indexWhere(
      (t) => t.shortId == state.selectedTask?.shortId,
    );
    final next = current < 0
        ? (delta > 0 ? 0 : tasks.length - 1)
        : (current + delta).clamp(0, tasks.length - 1);
    state.selectTask(tasks[next].shortId);
    return true;
  }

  /// Keeps the keyboard flow going after a delete.
  void _selectNeighbour(TodoState state, TodoTask task) {
    final tasks = _visible(state);
    final i = tasks.indexWhere((t) => t.shortId == task.shortId);
    if (i < 0 || tasks.length < 2) return;
    final next = i + 1 < tasks.length ? tasks[i + 1] : tasks[i - 1];
    state.selectTask(next.shortId);
  }
}

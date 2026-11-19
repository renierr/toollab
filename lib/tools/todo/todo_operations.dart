import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';

/// Domain rules shared by the UI state and the headless background run.
class TodoOperations {
  TodoOperations._();

  /// Completing a recurring task keeps a done copy as history and moves the
  /// task itself to its next occurrence, reminders and all. Returns every
  /// task to write.
  static List<TodoTask> complete(
    TodoTask task, {
    required DateTime now,
    required String Function() newId,
  }) {
    final stamp = now.millisecondsSinceEpoch;
    final rule = task.recurrence;
    final due = task.due;
    final next = rule == null || due == null ? null : rule.nextAfter(due, due);
    if (next == null) {
      return [task.copyWith(completedAt: () => stamp, updatedAt: stamp)];
    }
    final shift = next.difference(due!);
    final history = task.copyWith(
      shortId: newId(),
      completedAt: () => stamp,
      recurrence: () => null,
      reminders: const [],
      createdAt: stamp,
      updatedAt: stamp,
    );
    final advanced = task.copyWith(
      dueAt: () => next.millisecondsSinceEpoch,
      reminders: [
        for (final r in task.reminders)
          TodoReminder(
            at: r.time.add(shift).millisecondsSinceEpoch,
            alarm: r.alarm,
          ),
      ],
      steps: [for (final s in task.steps) s.copyWith(done: false)],
      myDay: () => null,
      updatedAt: stamp,
    );
    return [history, advanced];
  }

  /// Applies "done" taps from notifications and the home screen widget.
  /// Returns true when anything changed.
  static Future<bool> applyPendingActions() async {
    final actions = await TodoNative.drainActions();
    if (actions.isEmpty) return false;
    final db = TodoDbHelper.instance;
    var changed = false;
    for (final action in actions) {
      if (action.type != 'complete') continue;
      final task = await db.getTask(action.taskId);
      if (task == null || task.deleted || task.completed) continue;
      await db.upsertTasks(
        complete(
          task,
          now: DateTime.fromMillisecondsSinceEpoch(action.at),
          newId: db.generateShortId,
        ),
      );
      changed = true;
    }
    return changed;
  }
}

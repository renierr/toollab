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
    final next = rule == null || due == null
        ? null
        : rule.fromCompletion
        ? rule.nextFromCompletion(due, now)
        : rule.nextAfter(due, due);
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

  /// Moves the due date to [day], keeping its time of day; reminders move
  /// by the same number of days. A time already past today becomes all-day.
  static TodoTask moveDue(
    TodoTask task,
    DateTime day, {
    required DateTime now,
  }) {
    final old = task.due;
    final stamp = now.millisecondsSinceEpoch;
    final leavesMyDay =
        task.isInMyDay(now) && TodoTask.dayKey(day) != TodoTask.dayKey(now);
    final myDay = leavesMyDay ? () => null : null;
    if (old == null) {
      return task.copyWith(
        dueAt: () =>
            DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
        dueHasTime: false,
        myDay: myDay,
        updatedAt: stamp,
      );
    }
    var hasTime = task.dueHasTime;
    var due = hasTime
        ? DateTime(day.year, day.month, day.day, old.hour, old.minute)
        : DateTime(day.year, day.month, day.day);
    if (hasTime && due.isBefore(now)) {
      hasTime = false;
      due = DateTime(day.year, day.month, day.day);
    }
    final days = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(old.year, old.month, old.day)).inDays;
    return task.copyWith(
      dueAt: () => due.millisecondsSinceEpoch,
      dueHasTime: hasTime,
      reminders: [
        for (final r in task.reminders)
          TodoReminder(
            at: DateTime(
              r.time.year,
              r.time.month,
              r.time.day + days,
              r.time.hour,
              r.time.minute,
            ).millisecondsSinceEpoch,
            alarm: r.alarm,
          ),
      ],
      myDay: myDay,
      updatedAt: stamp,
    );
  }

  /// Applies "done" taps from notifications and the home screen widget.
  /// Returns true when anything changed.
  static Future<bool> applyPendingActions() async {
    final actions = await TodoNative.drainActions();
    if (actions.isEmpty) return false;
    final db = TodoDbHelper.instance;
    var changed = false;
    for (final action in actions) {
      final task = await db.getTask(action.taskId);
      if (task == null || task.deleted || task.completed) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(action.at);
      switch (action.type) {
        case 'complete':
          await db.upsertTasks(
            complete(task, now: at, newId: db.generateShortId),
          );
        case 'tomorrow':
          await db.upsertTasks([
            moveDue(task, DateTime(at.year, at.month, at.day + 1), now: at),
          ]);
        default:
          continue;
      }
      changed = true;
    }
    return changed;
  }
}

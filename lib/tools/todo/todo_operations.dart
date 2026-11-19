import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';

/// Domain rules shared by the UI state and the headless background run.
class TodoOperations {
  TodoOperations._();

  static const int defaultCleanupDays = 90;
  static const List<int> cleanupOptions = [0, 30, 90, 180, 365];
  static const Duration trashRetention = Duration(days: 30);
  static const String _cleanupKey = 'cleanup_days';

  static Future<int> loadCleanupDays() async {
    final raw = await DatabaseService.instance.getSetting(
      TodoTool.config.id,
      _cleanupKey,
    );
    final days = int.tryParse(raw ?? '');
    return days == null || days < 0 ? defaultCleanupDays : days;
  }

  static Future<void> saveCleanupDays(int days) => DatabaseService.instance
      .setSetting(TodoTool.config.id, _cleanupKey, '$days');

  /// Deletes tasks completed more than [days] ago (0 keeps them) and drops
  /// trash past [trashRetention]. Returns true when tasks were deleted.
  static Future<bool> cleanup(int days, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final db = TodoDbHelper.instance;
    await db.removeFromTrash(
      olderThan: n.subtract(trashRetention).millisecondsSinceEpoch,
    );
    if (days <= 0) return false;
    final old = await db.getCompletedBefore(
      n.subtract(Duration(days: days)).millisecondsSinceEpoch,
    );
    if (old.isEmpty) return false;
    final stamp = n.millisecondsSinceEpoch;
    await db.upsertTasks([
      for (final t in old) t.copyWith(deleted: true, updatedAt: stamp),
    ]);
    return true;
  }

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
    final start = task.start;
    final advanced = task.copyWith(
      dueAt: () => next.millisecondsSinceEpoch,
      startAt: start == null
          ? null
          : () => DateTime(
              start.year,
              start.month,
              start.day + _days(due, next),
            ).millisecondsSinceEpoch,
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
    final dayStart = DateTime(day.year, day.month, day.day);
    // A start date after the new due day would hide it past its due date.
    final startAt =
        task.startAt != null && task.startAt! > dayStart.millisecondsSinceEpoch
        ? () => null
        : null;
    if (old == null) {
      return task.copyWith(
        dueAt: () => dayStart.millisecondsSinceEpoch,
        dueHasTime: false,
        myDay: myDay,
        startAt: startAt,
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
    final days = _days(old, day);
    return task.copyWith(
      startAt: startAt,
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

  /// Calendar days from [from] to [to], ignoring DST.
  static int _days(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

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

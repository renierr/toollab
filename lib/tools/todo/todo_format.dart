import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

class TodoFormat {
  TodoFormat._();

  static String time(DateTime d, AppLocalizations l10n) =>
      DateFormat.Hm(l10n.localeName).format(d);

  /// "Today", "Tomorrow", "Mon", "12 Mar", "12 Mar 2027".
  static String day(DateTime d, AppLocalizations l10n, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return l10n.todoToday;
    if (diff == 1) return l10n.todoTomorrow;
    if (diff == -1) return l10n.todoYesterday;
    if (diff > 1 && diff < 7) return DateFormat.EEEE(l10n.localeName).format(d);
    if (d.year == n.year) return DateFormat.MMMEd(l10n.localeName).format(d);
    return DateFormat.yMMMEd(l10n.localeName).format(d);
  }

  static String dayTime(DateTime d, AppLocalizations l10n, {DateTime? now}) =>
      '${day(d, l10n, now: now)}, ${time(d, l10n)}';

  static String due(TodoTask task, AppLocalizations l10n, {DateTime? now}) {
    final d = task.due;
    if (d == null) return '';
    return task.dueHasTime
        ? dayTime(d, l10n, now: now)
        : day(d, l10n, now: now);
  }

  static String smartName(TodoSmartList smart, AppLocalizations l10n) =>
      switch (smart) {
        TodoSmartList.myDay => l10n.todoMyDay,
        TodoSmartList.important => l10n.todoImportant,
        TodoSmartList.planned => l10n.todoPlanned,
        TodoSmartList.all => l10n.todoAllTasks,
        TodoSmartList.completed => l10n.todoCompleted,
      };

  static String recurrence(TodoRecurrence r, AppLocalizations l10n) {
    if (r.isWeekdays) return l10n.todoRepeatWeekdays;
    final base = switch (r.freq) {
      RecurrenceFreq.daily =>
        r.interval == 1
            ? l10n.todoRepeatDaily
            : l10n.todoRepeatEveryDays(r.interval),
      RecurrenceFreq.weekly =>
        r.interval == 1
            ? l10n.todoRepeatWeekly
            : l10n.todoRepeatEveryWeeks(r.interval),
      RecurrenceFreq.monthly =>
        r.interval == 1
            ? l10n.todoRepeatMonthly
            : l10n.todoRepeatEveryMonths(r.interval),
      RecurrenceFreq.yearly =>
        r.interval == 1
            ? l10n.todoRepeatYearly
            : l10n.todoRepeatEveryYears(r.interval),
    };
    final details = <String>[];
    if (r.freq == RecurrenceFreq.weekly && r.weekdays.isNotEmpty) {
      final sorted = r.weekdays.toList()..sort();
      details.add(sorted.map((d) => weekdayShort(d, l10n)).join(', '));
    }
    if (r.freq == RecurrenceFreq.monthly && r.monthlyNth != null) {
      final weekday = r.weekdays.isEmpty ? 1 : r.weekdays.first;
      details.add(
        '${nthLabel(r.monthlyNth!, l10n)} ${weekdayLong(weekday, l10n)}',
      );
    }
    if (r.until != null) {
      details.add(
        l10n.todoRepeatUntil(
          DateFormat.yMMMd(l10n.localeName).format(r.until!),
        ),
      );
    }
    return details.isEmpty ? base : '$base · ${details.join(' · ')}';
  }

  static String nthLabel(int nth, AppLocalizations l10n) => switch (nth) {
    1 => l10n.todoNthFirst,
    2 => l10n.todoNthSecond,
    3 => l10n.todoNthThird,
    4 => l10n.todoNthFourth,
    _ => l10n.todoNthLast,
  };

  // 2024-01-01 was a Monday.
  static String weekdayShort(int isoDay, AppLocalizations l10n) =>
      DateFormat.E(l10n.localeName).format(DateTime(2024, 1, isoDay));

  static String weekdayLong(int isoDay, AppLocalizations l10n) =>
      DateFormat.EEEE(l10n.localeName).format(DateTime(2024, 1, isoDay));
}

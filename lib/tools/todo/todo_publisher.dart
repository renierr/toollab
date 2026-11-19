import 'dart:io';
import 'dart:ui';

import 'package:intl/date_symbol_data_local.dart';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_format.dart';
import 'package:tool_lab/tools/todo/todo_list_name.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_sort.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

class TodoAlarmEntry {
  final String taskId;
  final int at;
  final bool alarm;
  final String title;
  final String body;
  final int color;

  const TodoAlarmEntry({
    required this.taskId,
    required this.at,
    required this.alarm,
    required this.title,
    required this.body,
    required this.color,
  });

  String get key => '$taskId@$at';

  Map<String, Object?> toJson() => {
    'key': key,
    'taskId': taskId,
    'at': at,
    'alarm': alarm,
    'title': title,
    'body': body,
    'color': color,
  };
}

/// Builds the native reminder schedule and the home screen widget snapshot.
class TodoPublisher {
  TodoPublisher._();

  static const Duration horizon = Duration(days: 30);
  static const int _maxEntries = 500;
  static const int _maxPerTask = 60;
  static const int _widgetTasksPerList = 50;
  static const int defaultColor = 0xFF4FC3F7;

  static List<TodoAlarmEntry> buildEntries(
    List<TodoTask> tasks,
    Map<String, TodoList> lists,
    AppLocalizations l10n, {
    DateTime? now,
    Duration window = horizon,
  }) {
    final n = now ?? DateTime.now();
    final from = n.subtract(const Duration(minutes: 1));
    final to = n.add(window);
    final entries = <TodoAlarmEntry>[];
    for (final task in tasks) {
      if (task.completed || task.deleted || task.reminders.isEmpty) continue;
      final list = lists[task.listId];
      final body = [
        if (list != null) todoListName(list, l10n),
        if (task.dueAt != null) TodoFormat.due(task, l10n, now: n),
      ].join(' · ');
      var count = 0;
      for (final reminder in task.reminders) {
        for (final at in _fireTimes(task, reminder, from, to)) {
          if (count++ >= _maxPerTask) break;
          entries.add(
            TodoAlarmEntry(
              taskId: task.shortId,
              at: at.millisecondsSinceEpoch,
              alarm: reminder.alarm,
              title: task.title,
              body: body,
              color: list?.color ?? defaultColor,
            ),
          );
        }
      }
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
    return entries.length > _maxEntries
        ? entries.sublist(0, _maxEntries)
        : entries;
  }

  /// A recurring task reminds on every occurrence, at the same offset from
  /// the due date as its stored reminder.
  static Iterable<DateTime> _fireTimes(
    TodoTask task,
    TodoReminder reminder,
    DateTime from,
    DateTime to,
  ) sync* {
    final rule = task.recurrence;
    final due = task.due;
    // A rule counted from completion has no known future occurrences.
    if (rule == null || due == null || rule.fromCompletion) {
      final at = reminder.time;
      if (!at.isBefore(from) && at.isBefore(to)) yield at;
      return;
    }
    final offset = reminder.time.difference(due);
    for (final occurrence in rule.occurrences(due)) {
      final at = occurrence.add(offset);
      if (at.isAfter(to)) return;
      if (!at.isBefore(from)) yield at;
    }
  }

  static Map<String, Object?> buildWidgetSnapshot(
    List<TodoTask> tasks,
    List<TodoList> lists,
    AppLocalizations l10n, {
    Map<String, TodoSort> sortModes = const {},
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final open = tasks.where((t) => !t.completed && !t.deleted).toList();

    Map<String, Object?> listJson({
      required String id,
      required String name,
      required int color,
      required String icon,
      required TodoView view,
    }) {
      final matching = open.where((t) => view.matches(t, n)).toList();
      TodoSorting.sort(matching, TodoSorting.forView(view, sortModes));
      return {
        'id': id,
        'name': name,
        'color': color,
        'icon': icon,
        'openCount': matching.length,
        'tasks': [
          for (final t in matching.take(_widgetTasksPerList))
            {
              'id': t.shortId,
              'title': t.title,
              'meta': t.isOverdue(n)
                  ? '${l10n.todoGroupOverdue} · ${TodoFormat.due(t, l10n, now: n)}'
                  : TodoFormat.due(t, l10n, now: n),
              'overdue': t.isOverdue(n),
              'important': t.important,
            },
        ],
      };
    }

    const smartIcons = {
      TodoSmartList.myDay: '☀',
      TodoSmartList.important: '★',
      TodoSmartList.planned: '📅',
      TodoSmartList.all: '∞',
    };
    return {
      'version': 1,
      'generatedAt': n.millisecondsSinceEpoch,
      'lists': [
        for (final entry in smartIcons.entries)
          listJson(
            id: 'smart:${entry.key.name}',
            name: TodoFormat.smartName(entry.key, l10n),
            color: defaultColor,
            icon: entry.value,
            view: TodoView.smart(entry.key),
          ),
        for (final list in lists)
          listJson(
            id: list.shortId,
            name: todoListName(list, l10n),
            color: list.color,
            icon: list.emoji,
            view: TodoView.list(list.shortId),
          ),
      ],
    };
  }

  /// Writes both files and nudges native to re-read them. Android only.
  static Future<void> publish({
    required List<TodoTask> tasks,
    required List<TodoList> lists,
    required AppLocalizations l10n,
    required Map<String, TodoSort> sortModes,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final listMap = {for (final l in lists) l.shortId: l};
      final entries = buildEntries(tasks, listMap, l10n);
      await TodoNative.writeJson(TodoNative.alarmsFile, {
        'version': 1,
        'generatedAt': DateTime.now().millisecondsSinceEpoch,
        'entries': [for (final e in entries) e.toJson()],
      });
      await TodoNative.writeJson(
        TodoNative.widgetFile,
        buildWidgetSnapshot(tasks, lists, l10n, sortModes: sortModes),
      );
      await TodoNative.reschedule();
      await TodoNative.refreshWidgets();
    } catch (e) {
      errorLog('[TodoPublisher] publish failed: $e');
    }
  }

  /// Loads everything from the database; for runs without [TodoState].
  static Future<void> publishFromDatabase() async {
    final db = TodoDbHelper.instance;
    await publish(
      tasks: await db.getTasks(),
      lists: await db.getLists(),
      l10n: await localizations(),
      sortModes: await TodoSorting.load(),
    );
  }

  /// Works without a widget tree: a headless background run has neither
  /// localizations nor initialized intl date data.
  static Future<AppLocalizations> localizations() async {
    Locale? locale;
    try {
      locale = (await SettingsService.init()).getLocale();
    } catch (_) {}
    locale ??= PlatformDispatcher.instance.locale;
    AppLocalizations l10n;
    try {
      l10n = lookupAppLocalizations(Locale(locale.languageCode));
    } catch (_) {
      l10n = lookupAppLocalizations(const Locale('en'));
    }
    try {
      await initializeDateFormatting(l10n.localeName);
    } catch (e) {
      errorLog('[TodoPublisher] date data for ${l10n.localeName}: $e');
    }
    return l10n;
  }
}

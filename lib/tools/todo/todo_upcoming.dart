import 'dart:io';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_publisher.dart';

class TodoUpcomingReminder {
  final TodoAlarmEntry entry;
  final bool snoozed;

  const TodoUpcomingReminder(this.entry, {this.snoozed = false});

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(entry.at);
}

/// What is going to fire next. On Android this reads the files the native
/// scheduler works from, snoozes included, rather than recomputing them.
class TodoUpcoming {
  TodoUpcoming._();

  static const int limit = 50;

  static Future<List<TodoUpcomingReminder>> load({
    required List<TodoTask> tasks,
    required List<TodoList> lists,
    required AppLocalizations l10n,
  }) async {
    final now = DateTime.now();
    final List<TodoUpcomingReminder> result;
    if (Platform.isAndroid) {
      final snoozed = [
        for (final e in await TodoNative.readEntries(TodoNative.snoozesFile))
          TodoUpcomingReminder(TodoAlarmEntry.fromJson(e), snoozed: true),
      ];
      result = [
        ...snoozed,
        for (final e in await TodoNative.readEntries(TodoNative.alarmsFile))
          TodoUpcomingReminder(TodoAlarmEntry.fromJson(e)),
      ].where((r) => !r.time.isBefore(now)).toList();
    } else {
      result = [
        for (final e in TodoPublisher.buildEntries(tasks, {
          for (final l in lists) l.shortId: l,
        }, l10n))
          if (!DateTime.fromMillisecondsSinceEpoch(e.at).isBefore(now))
            TodoUpcomingReminder(e),
      ];
    }
    result.sort((a, b) => a.entry.at.compareTo(b.entry.at));
    return result.length > limit ? result.sublist(0, limit) : result;
  }
}

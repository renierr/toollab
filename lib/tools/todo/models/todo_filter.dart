import 'dart:convert';

import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';

enum TodoFilterDue { any, overdue, today, thisWeek, next7Days, noDate }

/// A saved smart list: list, tag, due range and importance combined.
class TodoFilter {
  static const String settingKey = 'filters';

  final String id;
  final String name;
  final String? listId;
  final String? tag;
  final TodoFilterDue due;
  final bool importantOnly;

  const TodoFilter({
    required this.id,
    required this.name,
    this.listId,
    this.tag,
    this.due = TodoFilterDue.any,
    this.importantOnly = false,
  });

  bool matches(TodoTask task, DateTime now) {
    if (listId != null && task.listId != listId) return false;
    if (tag != null &&
        !task.tags.any((t) => t.toLowerCase() == tag!.toLowerCase())) {
      return false;
    }
    if (importantOnly && !task.important) return false;
    return dueMatches(due, task, now);
  }

  static bool dueMatches(TodoFilterDue due, TodoTask task, DateTime now) {
    final d = task.due;
    final today = DateTime(now.year, now.month, now.day);
    return switch (due) {
      TodoFilterDue.any => true,
      TodoFilterDue.noDate => d == null,
      TodoFilterDue.overdue => task.isOverdue(now),
      TodoFilterDue.today =>
        d != null && d.isBefore(today.add(const Duration(days: 1))),
      TodoFilterDue.thisWeek => d != null && d.isBefore(endOfWeek(now)),
      TodoFilterDue.next7Days =>
        d != null && d.isBefore(today.add(const Duration(days: 8))),
    };
  }

  /// Next Monday 00:00.
  static DateTime endOfWeek(DateTime now) =>
      DateTime(now.year, now.month, now.day + 8 - now.weekday);

  factory TodoFilter.fromJson(Map<String, dynamic> json) => TodoFilter(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    listId: json['listId'] as String?,
    tag: json['tag'] as String?,
    due: TodoFilterDue.values.firstWhere(
      (d) => d.name == json['due'],
      orElse: () => TodoFilterDue.any,
    ),
    importantOnly: json['importantOnly'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'listId': listId,
    'tag': tag,
    'due': due.name,
    'importantOnly': importantOnly,
  };

  static List<TodoFilter> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map<String, dynamic>) TodoFilter.fromJson(e),
      ].where((f) => f.id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<TodoFilter>> load() async => decode(
    await DatabaseService.instance.getSetting(TodoTool.config.id, settingKey),
  );

  static Future<void> save(List<TodoFilter> filters) =>
      DatabaseService.instance.setSetting(
        TodoTool.config.id,
        settingKey,
        jsonEncode([for (final f in filters) f.toJson()]),
      );
}

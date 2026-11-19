import 'dart:convert';

import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

enum TodoSort { manual, dueDate, importance, alphabetical, created }

/// Per-view sort modes, keyed by [TodoView.widgetKey]; shared by the app
/// list and the home screen widget snapshot.
class TodoSorting {
  TodoSorting._();

  static const String settingKey = 'sort_modes';

  static TodoSort forView(TodoView view, Map<String, TodoSort> modes) =>
      modes[view.widgetKey] ??
      (view.smart == TodoSmartList.planned
          ? TodoSort.dueDate
          : TodoSort.manual);

  static Map<String, TodoSort> decode(String? raw) {
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key: TodoSort.values.firstWhere(
            (s) => s.name == e.value,
            orElse: () => TodoSort.manual,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  static String encode(Map<String, TodoSort> modes) =>
      jsonEncode({for (final e in modes.entries) e.key: e.value.name});

  static Future<Map<String, TodoSort>> load() async => decode(
    await DatabaseService.instance.getSetting(TodoTool.config.id, settingKey),
  );

  static Future<void> save(Map<String, TodoSort> modes) => DatabaseService
      .instance
      .setSetting(TodoTool.config.id, settingKey, encode(modes));

  static void sort(List<TodoTask> tasks, TodoSort sort) {
    int byDue(TodoTask a, TodoTask b) {
      if (a.dueAt == null && b.dueAt == null) return 0;
      if (a.dueAt == null) return 1;
      if (b.dueAt == null) return -1;
      return a.dueAt!.compareTo(b.dueAt!);
    }

    switch (sort) {
      case TodoSort.manual:
        tasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      case TodoSort.dueDate:
        tasks.sort((a, b) {
          final c = byDue(a, b);
          return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
        });
      case TodoSort.importance:
        tasks.sort((a, b) {
          if (a.important != b.important) return a.important ? -1 : 1;
          final c = byDue(a, b);
          return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
        });
      case TodoSort.alphabetical:
        tasks.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case TodoSort.created:
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }
}

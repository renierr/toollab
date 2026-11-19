import 'dart:convert';

import 'package:tool_lab/tools/todo/models/todo_task.dart';

/// A deleted task kept locally so it can be restored.
class TodoTrashItem {
  final TodoTask task;
  final int deletedAt;

  const TodoTrashItem({required this.task, required this.deletedAt});

  DateTime get deletedTime => DateTime.fromMillisecondsSinceEpoch(deletedAt);

  static TodoTrashItem? fromMap(Map<String, Object?> map) {
    final id = map['short_id'] as String?;
    final raw = map['data'] as String?;
    if (id == null || raw == null) return null;
    try {
      final deletedAt = map['deleted_at'] as int? ?? 0;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TodoTrashItem(
        task: TodoTask.fromJson(
          id,
          json,
          updatedAt: json['updatedAt'] as int? ?? deletedAt,
        ),
        deletedAt: deletedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toRow() => {
    'short_id': task.shortId,
    'deleted_at': deletedAt,
    'data': jsonEncode({...task.toJson(), 'updatedAt': task.updatedAt}),
  };
}

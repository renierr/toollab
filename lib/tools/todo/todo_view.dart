import 'package:tool_lab/tools/todo/models/todo_task.dart';

enum TodoSmartList { myDay, important, planned, all, completed }

enum TodoViewKind { smart, list, tag }

/// What the task pane shows: a smart list, a user list or a tag.
class TodoView {
  final TodoViewKind kind;
  final String id;

  const TodoView._(this.kind, this.id);

  const TodoView.list(String shortId) : this._(TodoViewKind.list, shortId);
  const TodoView.tag(String tag) : this._(TodoViewKind.tag, tag);
  TodoView.smart(TodoSmartList smart) : this._(TodoViewKind.smart, smart.name);

  static final TodoView myDay = TodoView.smart(TodoSmartList.myDay);

  TodoSmartList? get smart => kind == TodoViewKind.smart
      ? TodoSmartList.values.firstWhere(
          (s) => s.name == id,
          orElse: () => TodoSmartList.all,
        )
      : null;

  /// Key used by the home screen widget (`smart:myDay`, list short id).
  String get widgetKey => switch (kind) {
    TodoViewKind.smart => 'smart:$id',
    TodoViewKind.list => id,
    TodoViewKind.tag => 'tag:$id',
  };

  static TodoView fromWidgetKey(String key) {
    if (key.startsWith('smart:')) {
      final id = key.substring(6);
      final smart = TodoSmartList.values.firstWhere(
        (s) => s.name.toLowerCase() == id.toLowerCase(),
        orElse: () => TodoSmartList.myDay,
      );
      return TodoView.smart(smart);
    }
    if (key.startsWith('tag:')) return TodoView.tag(key.substring(4));
    return TodoView.list(key);
  }

  bool matches(TodoTask task, DateTime now) => switch (kind) {
    TodoViewKind.list => task.listId == id,
    TodoViewKind.tag => task.tags.any(
      (t) => t.toLowerCase() == id.toLowerCase(),
    ),
    TodoViewKind.smart => switch (smart!) {
      TodoSmartList.myDay => task.isInMyDay(now),
      TodoSmartList.important => task.important,
      TodoSmartList.planned => task.dueAt != null,
      TodoSmartList.all => true,
      TodoSmartList.completed => task.completed,
    },
  };

  /// Smart lists other than "completed" hide done tasks entirely.
  bool get showsCompletedSection =>
      kind != TodoViewKind.smart || smart == TodoSmartList.myDay;

  @override
  bool operator ==(Object other) =>
      other is TodoView && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

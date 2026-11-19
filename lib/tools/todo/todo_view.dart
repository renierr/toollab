import 'package:tool_lab/tools/todo/models/todo_filter.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';

enum TodoSmartList {
  myDay,
  important,
  planned,
  thisWeek,
  noDate,
  all,
  completed,
}

enum TodoViewKind { smart, list, tag, filter }

/// What the task pane shows: a smart list, a user list, a tag or a saved
/// filter.
class TodoView {
  final TodoViewKind kind;
  final String id;

  const TodoView._(this.kind, this.id);

  const TodoView.list(String shortId) : this._(TodoViewKind.list, shortId);
  const TodoView.tag(String tag) : this._(TodoViewKind.tag, tag);
  const TodoView.filter(String id) : this._(TodoViewKind.filter, id);
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
    TodoViewKind.filter => 'filter:$id',
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
    if (key.startsWith('filter:')) return TodoView.filter(key.substring(7));
    return TodoView.list(key);
  }

  /// [filters] resolves a filter view; without it a filter matches nothing.
  bool matches(
    TodoTask task,
    DateTime now, [
    Map<String, TodoFilter> filters = const {},
  ]) => switch (kind) {
    TodoViewKind.list => task.listId == id,
    TodoViewKind.tag => task.tags.any(
      (t) => t.toLowerCase() == id.toLowerCase(),
    ),
    TodoViewKind.filter => filters[id]?.matches(task, now) ?? false,
    TodoViewKind.smart => switch (smart!) {
      TodoSmartList.myDay => task.isInMyDay(now),
      TodoSmartList.important => task.important,
      TodoSmartList.planned => task.dueAt != null,
      TodoSmartList.thisWeek => TodoFilter.dueMatches(
        TodoFilterDue.thisWeek,
        task,
        now,
      ),
      TodoSmartList.noDate => task.dueAt == null,
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

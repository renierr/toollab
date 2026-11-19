import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_attachment.dart';
import 'package:tool_lab/tools/todo/models/todo_folder.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_background.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_desktop_reminders.dart';
import 'package:tool_lab/tools/todo/todo_native.dart';
import 'package:tool_lab/tools/todo/todo_operations.dart';
import 'package:tool_lab/tools/todo/todo_publisher.dart';
import 'package:tool_lab/tools/todo/todo_quick_parser.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';
import 'package:tool_lab/tools/todo/todo_sort.dart';
import 'package:tool_lab/tools/todo/todo_swipe_action.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

export 'package:tool_lab/tools/todo/todo_sort.dart' show TodoSort;
export 'package:tool_lab/tools/todo/todo_swipe_action.dart';

/// What an undo restores: the tasks as they were, minus the ones it created.
class TodoUndo {
  final List<TodoTask> previous;
  final List<String> createdIds;

  const TodoUndo(this.previous, [this.createdIds = const []]);
}

class TodoState extends ChangeNotifier {
  /// Fixed id so the default list of every device merges into one on sync.
  static const String defaultListId = 'INBOX';
  static const int maxAttachmentBytes = 25 * 1024 * 1024;
  static const String _swipeStartKey = 'swipe_start';
  static const String _swipeEndKey = 'swipe_end';
  static const String _reminderTimeKey = 'default_reminder_time';
  static const String _plannedCalendarKey = 'planned_calendar';
  static const int defaultReminderMinutesFallback = 11 * 60;
  static const String _lastViewKey = 'last_view';

  static const List<int> listColors = [
    0xFF4FC3F7,
    0xFF66BB6A,
    0xFFFFCA28,
    0xFFFF9800,
    0xFFEF5350,
    0xFFEC407A,
    0xFFAB47BC,
    0xFF7E57C2,
    0xFF26A69A,
    0xFF8D6E63,
    0xFF78909C,
  ];

  final TodoDbHelper _db = TodoDbHelper.instance;

  List<TodoFolder> _folders = [];
  List<TodoList> _lists = [];
  List<TodoTask> _tasks = [];
  Map<String, List<TodoAttachment>> _attachments = {};
  Map<String, TodoSort> _sortModes = {};
  TodoSwipeAction _swipeStart = TodoSwipeAction.complete;
  TodoSwipeAction _swipeEnd = TodoSwipeAction.delete;
  int _defaultReminderMinutes = defaultReminderMinutesFallback;
  bool _plannedCalendar = false;

  bool _loaded = false;
  bool _loading = false;
  bool _syncing = false;
  String? _syncError;
  TodoView _view = TodoView.myDay;
  String? _selectedTaskId;
  String _query = '';
  final Set<TodoView> _expandedCompleted = {};

  Timer? _publishDebounce;
  Timer? _syncDebounce;
  final StreamController<TodoLaunchIntent> _launchIntents =
      StreamController<TodoLaunchIntent>.broadcast();

  TodoState() {
    TodoNative.onActionsPending = _onActionsPending;
    TodoNative.onLaunchIntent = _launchIntents.add;
    TodoNative.ensureHandler();
  }

  List<TodoFolder> get folders => _folders;
  List<TodoList> get lists => _lists;
  List<TodoTask> get tasks => _tasks;
  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get syncing => _syncing;
  String? get syncError => _syncError;
  TodoView get view => _view;
  String get query => _query;
  Stream<TodoLaunchIntent> get launchIntents => _launchIntents.stream;

  TodoTask? get selectedTask =>
      _selectedTaskId == null ? null : taskById(_selectedTaskId!);

  TodoTask? taskById(String id) {
    for (final t in _tasks) {
      if (t.shortId == id) return t;
    }
    return null;
  }

  TodoList? listById(String? id) {
    if (id == null) return null;
    for (final l in _lists) {
      if (l.shortId == id) return l;
    }
    return null;
  }

  List<TodoList> listsInFolder(String? folderId) =>
      _lists.where((l) => l.folderId == folderId).toList();

  List<TodoAttachment> attachmentsFor(String taskId) =>
      _attachments[taskId] ?? const [];

  TodoSort sortFor(TodoView view) => TodoSorting.forView(view, _sortModes);

  /// Action for a swipe from the leading edge towards the trailing one.
  TodoSwipeAction get swipeStart => _swipeStart;
  TodoSwipeAction get swipeEnd => _swipeEnd;

  /// Minutes after midnight for reminders that have no time of their own.
  int get defaultReminderMinutes => _defaultReminderMinutes;

  /// Planned shows a month calendar instead of the grouped list.
  bool get plannedCalendar => _plannedCalendar;

  bool completedExpanded(TodoView view) => _expandedCompleted.contains(view);

  List<String> get allTags {
    final seen = <String, String>{};
    for (final t in _tasks) {
      if (t.completed) continue;
      for (final tag in t.tags) {
        seen.putIfAbsent(tag.toLowerCase(), () => tag);
      }
    }
    final tags = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  String viewTitle(TodoView view, String Function(TodoSmartList) smartName) =>
      switch (view.kind) {
        TodoViewKind.smart => smartName(view.smart!),
        TodoViewKind.list => listById(view.id)?.name ?? '',
        TodoViewKind.tag => '#${view.id}',
      };

  int colorFor(TodoView view) => view.kind == TodoViewKind.list
      ? listById(view.id)?.color ?? TodoPublisher.defaultColor
      : TodoPublisher.defaultColor;

  int openCount(TodoView view) {
    final now = DateTime.now();
    return _tasks.where((t) => !t.completed && view.matches(t, now)).length;
  }

  /// Open tasks of the current view (or the search result), sorted.
  List<TodoTask> openTasks(TodoView view) {
    final now = DateTime.now();
    final needle = _query.trim().toLowerCase();
    final result = _tasks.where((t) {
      if (t.completed) return false;
      if (needle.isNotEmpty) return _matchesQuery(t, needle);
      return view.matches(t, now);
    }).toList();
    TodoSorting.sort(result, sortFor(view));
    return result;
  }

  List<TodoTask> completedTasks(TodoView view) {
    final now = DateTime.now();
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty &&
        !view.showsCompletedSection &&
        view.smart != TodoSmartList.completed) {
      return const [];
    }
    final result =
        _tasks.where((t) {
            if (!t.completed) return false;
            if (needle.isNotEmpty) return _matchesQuery(t, needle);
            if (view.smart == TodoSmartList.completed) return true;
            return view.matches(t, now);
          }).toList()
          ..sort((a, b) => (b.completedAt ?? 0).compareTo(a.completedAt ?? 0));
    return result;
  }

  bool _matchesQuery(TodoTask t, String needle) =>
      t.title.toLowerCase().contains(needle) ||
      t.note.toLowerCase().contains(needle) ||
      t.tags.any((tag) => tag.toLowerCase().contains(needle)) ||
      t.steps.any((s) => s.title.toLowerCase().contains(needle));

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      await TodoOperations.applyPendingActions();
      await _reloadFromDb();
      await _ensureDefaultList();
      await _loadSettings();
      _loaded = true;
    } catch (e) {
      errorLog('[TodoState] load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
    _schedulePublish();
    unawaited(syncNow(quiet: true));
  }

  Future<void> _reloadFromDb() async {
    _folders = await _db.getFolders();
    _lists = await _db.getLists();
    _tasks = await _db.getTasks();
    final attachments = <String, List<TodoAttachment>>{};
    for (final a in await _db.getAttachments()) {
      attachments.putIfAbsent(a.taskId, () => []).add(a);
    }
    _attachments = attachments;
    if (_view.kind == TodoViewKind.list && listById(_view.id) == null) {
      _view = TodoView.myDay;
    }
    if (_selectedTaskId != null && taskById(_selectedTaskId!) == null) {
      _selectedTaskId = null;
    }
  }

  Future<void> _ensureDefaultList() async {
    if (_lists.any((l) => l.shortId == defaultListId)) return;
    if (await _db.getList(defaultListId) != null) return;
    const list = TodoList(
      shortId: defaultListId,
      name: '',
      color: TodoPublisher.defaultColor,
      sortOrder: -1,
      createdAt: 0,
      // Oldest possible timestamp: a renamed inbox from another device wins.
      updatedAt: 1,
    );
    await _db.upsertList(list);
    _lists = [list, ..._lists];
  }

  Future<void> _loadSettings() async {
    _sortModes = await TodoSorting.load();
    _swipeStart = TodoSwipeAction.parse(
      await DatabaseService.instance.getSetting(
        TodoTool.config.id,
        _swipeStartKey,
      ),
      TodoSwipeAction.complete,
    );
    _swipeEnd = TodoSwipeAction.parse(
      await DatabaseService.instance.getSetting(
        TodoTool.config.id,
        _swipeEndKey,
      ),
      TodoSwipeAction.delete,
    );
    final minutes = int.tryParse(
      await DatabaseService.instance.getSetting(
            TodoTool.config.id,
            _reminderTimeKey,
          ) ??
          '',
    );
    if (minutes != null && minutes >= 0 && minutes < 24 * 60) {
      _defaultReminderMinutes = minutes;
    }
    _plannedCalendar =
        await DatabaseService.instance.getSetting(
          TodoTool.config.id,
          _plannedCalendarKey,
        ) ==
        'true';
    final last = await DatabaseService.instance.getSetting(
      TodoTool.config.id,
      _lastViewKey,
    );
    if (last != null) {
      final v = TodoView.fromWidgetKey(last);
      if (v.kind != TodoViewKind.list || listById(v.id) != null) _view = v;
    }
  }

  /// Drops the task data on close; widgets and reminders keep their files.
  void release() {
    _folders = [];
    _lists = [];
    _tasks = [];
    _attachments = {};
    _selectedTaskId = null;
    _query = '';
    _loaded = false;
    notifyListeners();
  }

  Future<void> _onActionsPending() async {
    if (!_loaded) return;
    if (await TodoOperations.applyPendingActions()) {
      await _reloadFromDb();
      notifyListeners();
      _schedulePublish();
      _scheduleSync();
    }
  }

  Future<void> handleLaunchIntent(TodoLaunchIntent intent) async {
    if (!_loaded) await load();
    if (intent.listId != null) {
      final v = TodoView.fromWidgetKey(intent.listId!);
      if (v.kind != TodoViewKind.list || listById(v.id) != null) selectView(v);
    }
    if (intent.taskId != null) {
      if (taskById(intent.taskId!) == null) await _reloadFromDb();
      if (taskById(intent.taskId!) != null) selectTask(intent.taskId);
    }
  }

  // -------------------------------------------------------------- selection

  void selectView(TodoView view) {
    _view = view;
    _query = '';
    _selectedTaskId = null;
    notifyListeners();
    unawaited(
      DatabaseService.instance.setSetting(
        TodoTool.config.id,
        _lastViewKey,
        view.widgetKey,
      ),
    );
  }

  void selectTask(String? id) {
    if (_selectedTaskId == id) return;
    _selectedTaskId = id;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void toggleCompletedExpanded(TodoView view) {
    if (!_expandedCompleted.remove(view)) _expandedCompleted.add(view);
    notifyListeners();
  }

  Future<void> setSort(TodoView view, TodoSort sort) async {
    _sortModes[view.widgetKey] = sort;
    notifyListeners();
    await TodoSorting.save(_sortModes);
    _schedulePublish();
  }

  Future<void> setSwipeAction({
    required bool start,
    required TodoSwipeAction action,
  }) async {
    if (start) {
      _swipeStart = action;
    } else {
      _swipeEnd = action;
    }
    notifyListeners();
    await DatabaseService.instance.setSetting(
      TodoTool.config.id,
      start ? _swipeStartKey : _swipeEndKey,
      action.name,
    );
  }

  Future<void> setPlannedCalendar(bool on) async {
    _plannedCalendar = on;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      TodoTool.config.id,
      _plannedCalendarKey,
      '$on',
    );
  }

  Future<void> setDefaultReminderMinutes(int minutes) async {
    _defaultReminderMinutes = minutes;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      TodoTool.config.id,
      _reminderTimeKey,
      '$minutes',
    );
  }

  // ------------------------------------------------------------------ tasks

  int get _now => DateTime.now().millisecondsSinceEpoch;

  double _nextSortOrder({bool top = false}) {
    if (_tasks.isEmpty) return 0;
    final orders = _tasks.map((t) => t.sortOrder);
    return top
        ? orders.reduce((a, b) => a < b ? a : b) - 1
        : orders.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// The list a new task in [view] goes to.
  String targetListFor(TodoView view) =>
      view.kind == TodoViewKind.list ? view.id : defaultListId;

  Future<TodoTask> addTask(
    TodoQuickDraft draft, {
    TodoView? view,
    String? listId,
    bool addToMyDay = false,
    List<TodoReminder> reminders = const [],
  }) async {
    final v = view ?? _view;
    final now = DateTime.now();
    final tags = {...draft.tags, if (v.kind == TodoViewKind.tag) v.id}.toList();
    var due = draft.due;
    var hasTime = draft.hasTime;
    if (due == null && v.smart == TodoSmartList.planned) {
      due = DateTime(now.year, now.month, now.day);
      hasTime = false;
    }
    final autoReminders = [
      ...reminders,
      if (reminders.isEmpty && hasTime && due != null && due.isAfter(now))
        TodoReminder(at: due.millisecondsSinceEpoch),
    ];
    final task = TodoTask(
      shortId: _db.generateShortId(),
      listId: listId ?? targetListFor(v),
      title: draft.title,
      important: draft.important || v.smart == TodoSmartList.important,
      myDay: addToMyDay || v.smart == TodoSmartList.myDay
          ? TodoTask.dayKey(now)
          : null,
      dueAt: due?.millisecondsSinceEpoch,
      dueHasTime: hasTime,
      recurrence: draft.recurrence,
      sortOrder: _nextSortOrder(top: true),
      reminders: autoReminders,
      tags: tags,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );
    await _saveTasks([task]);
    return task;
  }

  Future<void> _saveTasks(List<TodoTask> changed) async {
    await _db.upsertTasks(changed);
    for (final task in changed) {
      final i = _tasks.indexWhere((t) => t.shortId == task.shortId);
      if (task.deleted) {
        if (i >= 0) _tasks.removeAt(i);
      } else if (i >= 0) {
        _tasks[i] = task;
      } else {
        _tasks.add(task);
      }
    }
    notifyListeners();
    _schedulePublish();
    _scheduleSync();
  }

  Future<void> updateTask(TodoTask task) =>
      _saveTasks([task.copyWith(updatedAt: _now)]);

  Future<TodoUndo> toggleCompleted(TodoTask task) async {
    if (task.completed) {
      await _saveTasks([
        task.copyWith(completedAt: () => null, updatedAt: _now),
      ]);
      return TodoUndo([task]);
    }
    final changed = TodoOperations.complete(
      task,
      now: DateTime.now(),
      newId: _db.generateShortId,
    );
    await _saveTasks(changed);
    unawaited(TodoNative.cancelNotifications(task.shortId));
    return TodoUndo(
      [task],
      [
        for (final t in changed)
          if (t.shortId != task.shortId) t.shortId,
      ],
    );
  }

  Future<void> undo(TodoUndo undo) async {
    final stamp = _now;
    await _saveTasks([
      for (final t in undo.previous)
        t.copyWith(updatedAt: stamp, deleted: false),
      for (final id in undo.createdIds)
        if (taskById(id) case final created?)
          created.copyWith(deleted: true, updatedAt: stamp),
    ]);
    for (final id in undo.createdIds) {
      await _db.softDelete(TodoRecordKind.task, id);
    }
  }

  /// Moves the due dates of [tasks] to [day]; see [TodoOperations.moveDue].
  Future<TodoUndo> moveDue(List<TodoTask> tasks, DateTime day) async {
    final now = DateTime.now();
    await _saveTasks([
      for (final t in tasks) TodoOperations.moveDue(t, day, now: now),
    ]);
    return TodoUndo(tasks);
  }

  static DateTime get tomorrow {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  static DateTime get nextMonday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 8 - now.weekday);
  }

  Future<void> toggleImportant(TodoTask task) =>
      updateTask(task.copyWith(important: !task.important));

  Future<void> toggleMyDay(TodoTask task) => updateTask(
    task.copyWith(
      myDay: () => task.isInMyDay(DateTime.now())
          ? null
          : TodoTask.dayKey(DateTime.now()),
    ),
  );

  Future<void> setDue(TodoTask task, DateTime? due, {bool hasTime = false}) {
    var recurrence = task.recurrence;
    if (due == null) recurrence = null;
    // Reminders follow a moved due date, so "1 hour before" stays that.
    var reminders = task.reminders;
    final old = task.due;
    if (old != null && due != null && task.recurrence != null) {
      final shift = due.difference(old);
      reminders = [
        for (final r in reminders)
          TodoReminder(
            at: r.time.add(shift).millisecondsSinceEpoch,
            alarm: r.alarm,
          ),
      ];
    }
    return updateTask(
      task.copyWith(
        dueAt: () => due?.millisecondsSinceEpoch,
        dueHasTime: due != null && hasTime,
        recurrence: () => recurrence,
        reminders: reminders,
      ),
    );
  }

  Future<void> setRecurrence(TodoTask task, TodoRecurrence? recurrence) {
    final now = DateTime.now();
    final due =
        task.dueAt ??
        (recurrence == null
            ? null
            : DateTime(now.year, now.month, now.day).millisecondsSinceEpoch);
    return updateTask(
      task.copyWith(recurrence: () => recurrence, dueAt: () => due),
    );
  }

  Future<void> setReminders(TodoTask task, List<TodoReminder> reminders) {
    final sorted = reminders.toSet().toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return updateTask(task.copyWith(reminders: sorted));
  }

  Future<void> setTitle(TodoTask task, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == task.title) return Future.value();
    return updateTask(task.copyWith(title: trimmed));
  }

  Future<void> setNote(TodoTask task, String note) {
    if (note == task.note) return Future.value();
    return updateTask(task.copyWith(note: note));
  }

  Future<void> setTags(TodoTask task, List<String> tags) =>
      updateTask(task.copyWith(tags: tags));

  Future<void> moveToList(TodoTask task, String listId) =>
      updateTask(task.copyWith(listId: listId));

  Future<void> addStep(TodoTask task, String title) {
    if (title.trim().isEmpty) return Future.value();
    return updateTask(
      task.copyWith(
        steps: [
          ...task.steps,
          TodoStep(id: _db.generateShortId(), title: title.trim()),
        ],
      ),
    );
  }

  Future<void> updateStep(TodoTask task, TodoStep step) => updateTask(
    task.copyWith(
      steps: [for (final s in task.steps) s.id == step.id ? step : s],
    ),
  );

  Future<void> removeStep(TodoTask task, TodoStep step) => updateTask(
    task.copyWith(steps: task.steps.where((s) => s.id != step.id).toList()),
  );

  Future<void> reorderSteps(TodoTask task, int oldIndex, int newIndex) {
    final steps = [...task.steps];
    steps.insert(newIndex, steps.removeAt(oldIndex));
    return updateTask(task.copyWith(steps: steps));
  }

  Future<TodoUndo> deleteTask(TodoTask task) async {
    await _saveTasks([task.copyWith(deleted: true, updatedAt: _now)]);
    await _db.softDelete(TodoRecordKind.task, task.shortId);
    if (_selectedTaskId == task.shortId) _selectedTaskId = null;
    unawaited(TodoNative.cancelNotifications(task.shortId));
    notifyListeners();
    return TodoUndo([task]);
  }

  /// Manual order: moves the task between its new neighbours in [visible].
  /// [newIndex] is the position after removal, as `onReorderItem` reports.
  Future<void> reorder(List<TodoTask> visible, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return Future.value();
    final moved = visible[oldIndex];
    final rest = [...visible]..removeAt(oldIndex);
    final before = newIndex > 0 ? rest[newIndex - 1].sortOrder : null;
    final after = newIndex < rest.length ? rest[newIndex].sortOrder : null;
    final order = switch ((before, after)) {
      (null, null) => 0.0,
      (null, final double a) => a - 1,
      (final double b, null) => b + 1,
      (final double b, final double a) => (a + b) / 2,
    };
    return updateTask(moved.copyWith(sortOrder: order));
  }

  // ------------------------------------------------------- lists & folders

  Future<TodoList> createList(
    String name, {
    String emoji = '',
    int? color,
    String? folderId,
  }) async {
    final now = _now;
    final maxOrder = _lists.isEmpty
        ? 0.0
        : _lists.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b);
    final list = TodoList(
      shortId: _db.generateShortId(),
      folderId: folderId,
      name: name.trim(),
      emoji: emoji,
      color: color ?? listColors[_lists.length % listColors.length],
      sortOrder: maxOrder + 1,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertList(list);
    _lists = [..._lists, list];
    _view = TodoView.list(list.shortId);
    _selectedTaskId = null;
    _afterStructureChange();
    return list;
  }

  Future<void> updateList(TodoList list) async {
    final updated = list.copyWith(updatedAt: _now);
    await _db.upsertList(updated);
    _lists = [for (final l in _lists) l.shortId == list.shortId ? updated : l];
    _afterStructureChange();
  }

  Future<void> deleteList(TodoList list) async {
    if (list.shortId == defaultListId) return;
    final stamp = _now;
    final doomed = _tasks.where((t) => t.listId == list.shortId).toList();
    for (final task in doomed) {
      for (final a in attachmentsFor(task.shortId)) {
        await _db.softDelete(TodoRecordKind.attachment, a.shortId);
      }
      _attachments.remove(task.shortId);
    }
    await _saveTasks([
      for (final t in doomed) t.copyWith(deleted: true, updatedAt: stamp),
    ]);
    for (final t in doomed) {
      await _db.softDelete(TodoRecordKind.task, t.shortId);
    }
    await _db.softDelete(TodoRecordKind.list, list.shortId);
    _lists = _lists.where((l) => l.shortId != list.shortId).toList();
    if (_view == TodoView.list(list.shortId)) _view = TodoView.myDay;
    _afterStructureChange();
  }

  Future<TodoFolder> createFolder(String name) async {
    final now = _now;
    final folder = TodoFolder(
      shortId: _db.generateShortId(),
      name: name.trim(),
      sortOrder: _folders.length.toDouble(),
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertFolder(folder);
    _folders = [..._folders, folder];
    _afterStructureChange();
    return folder;
  }

  Future<void> renameFolder(TodoFolder folder, String name) async {
    final updated = folder.copyWith(name: name.trim(), updatedAt: _now);
    await _db.upsertFolder(updated);
    _folders = [
      for (final f in _folders) f.shortId == folder.shortId ? updated : f,
    ];
    _afterStructureChange();
  }

  /// Lists inside move back to the top level; nothing is deleted with it.
  Future<void> deleteFolder(TodoFolder folder) async {
    final stamp = _now;
    final moved = <TodoList>[];
    for (final l in _lists.where((l) => l.folderId == folder.shortId)) {
      final updated = l.copyWith(folderId: () => null, updatedAt: stamp);
      await _db.upsertList(updated);
      moved.add(updated);
    }
    final byId = {for (final l in moved) l.shortId: l};
    _lists = [for (final l in _lists) byId[l.shortId] ?? l];
    await _db.softDelete(TodoRecordKind.folder, folder.shortId);
    _folders = _folders.where((f) => f.shortId != folder.shortId).toList();
    _afterStructureChange();
  }

  Future<void> moveListToFolder(TodoList list, String? folderId) =>
      updateList(list.copyWith(folderId: () => folderId));

  void _afterStructureChange() {
    notifyListeners();
    _schedulePublish();
    _scheduleSync();
  }

  // ------------------------------------------------------------ attachments

  /// Returns false when the file is over [maxAttachmentBytes].
  Future<bool> addAttachment(
    TodoTask task, {
    required String name,
    required String mimeType,
    required Uint8List data,
  }) async {
    if (data.length > maxAttachmentBytes) return false;
    final thumbnail = mimeType.startsWith('image/')
        ? await compute(_thumbnail, data)
        : null;
    final now = _now;
    final shortId = _db.generateShortId();
    await _db.insertAttachment(
      shortId: shortId,
      taskId: task.shortId,
      name: name,
      mimeType: mimeType,
      data: data,
      thumbnail: thumbnail,
      createdAt: now,
      updatedAt: now,
    );
    final meta = await _db.getAttachment(shortId);
    if (meta != null) {
      _attachments.putIfAbsent(task.shortId, () => []).add(meta);
    }
    // Touch the task so its row reflects the change and other devices refetch.
    await updateTask(task);
    return true;
  }

  Future<void> deleteAttachment(TodoAttachment attachment) async {
    await _db.softDelete(TodoRecordKind.attachment, attachment.shortId);
    _attachments[attachment.taskId]?.removeWhere(
      (a) => a.shortId == attachment.shortId,
    );
    notifyListeners();
    _scheduleSync();
  }

  Future<Uint8List?> attachmentData(TodoAttachment attachment) =>
      _db.getAttachmentData(attachment.shortId);

  static Uint8List? _thumbnail(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, height: 240)
          : img.copyResize(decoded, width: 240);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------- publish & sync

  void _schedulePublish() {
    _publishDebounce?.cancel();
    _publishDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (Platform.isAndroid) {
        await TodoPublisher.publish(
          tasks: _loaded ? _tasks : await _db.getTasks(),
          lists: _loaded ? _lists : await _db.getLists(),
          sortModes: _loaded ? _sortModes : await TodoSorting.load(),
          l10n: await TodoPublisher.localizations(),
        );
      } else {
        await TodoDesktopReminders.instance.refresh();
      }
    });
  }

  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 4), () {
      unawaited(syncNow(quiet: true));
    });
  }

  /// Returns false when sync is not configured or switched off for this tool.
  Future<bool> syncNow({bool quiet = false}) async {
    if (_syncing) return true;
    _syncing = true;
    _syncError = null;
    if (!quiet) notifyListeners();
    try {
      final result = await TodoBackground.syncIfEnabled();
      if (result == null) return false;
      await _reloadFromDb();
      _schedulePublish();
      return true;
    } catch (e) {
      errorLog('[TodoState] sync failed: $e');
      _syncError = '$e';
      return true;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _publishDebounce?.cancel();
    _syncDebounce?.cancel();
    _launchIntents.close();
    super.dispose();
  }
}

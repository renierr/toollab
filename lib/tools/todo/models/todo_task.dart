import 'dart:convert';

import 'package:tool_lab/tools/todo/todo_recurrence.dart';

class TodoStep {
  final String id;
  final String title;
  final bool done;

  const TodoStep({required this.id, required this.title, this.done = false});

  factory TodoStep.fromJson(Map<String, dynamic> json) => TodoStep(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    done: json['done'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  TodoStep copyWith({String? title, bool? done}) =>
      TodoStep(id: id, title: title ?? this.title, done: done ?? this.done);
}

class TodoReminder {
  final int at;
  final bool alarm;

  const TodoReminder({required this.at, this.alarm = false});

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(at);

  factory TodoReminder.fromJson(Map<String, dynamic> json) => TodoReminder(
    at: json['at'] as int? ?? 0,
    alarm: json['alarm'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'at': at, 'alarm': alarm};

  @override
  bool operator ==(Object other) =>
      other is TodoReminder && other.at == at && other.alarm == alarm;

  @override
  int get hashCode => Object.hash(at, alarm);
}

class TodoTask {
  final String shortId;
  final String listId;
  final String title;
  final String note;
  final bool important;

  /// `yyyy-MM-dd` of the day the task was added to My Day.
  final String? myDay;

  /// Local time; midnight when [dueHasTime] is false.
  final int? dueAt;
  final bool dueHasTime;
  final TodoRecurrence? recurrence;
  final int? completedAt;
  final double sortOrder;
  final List<TodoStep> steps;
  final List<TodoReminder> reminders;
  final List<String> tags;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  const TodoTask({
    required this.shortId,
    required this.listId,
    required this.title,
    this.note = '',
    this.important = false,
    this.myDay,
    this.dueAt,
    this.dueHasTime = false,
    this.recurrence,
    this.completedAt,
    required this.sortOrder,
    this.steps = const [],
    this.reminders = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  bool get completed => completedAt != null;
  DateTime? get due =>
      dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt!);
  int get stepsDone => steps.where((s) => s.done).length;

  bool isInMyDay(DateTime now) => myDay != null && myDay == dayKey(now);

  bool isOverdue(DateTime now) {
    final d = due;
    if (d == null || completed) return false;
    if (dueHasTime) return d.isBefore(now);
    return d.isBefore(DateTime(now.year, now.month, now.day));
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory TodoTask.fromMap(Map<String, Object?> map) => TodoTask(
    shortId: map['short_id'] as String? ?? '',
    listId: map['list_id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    note: map['note'] as String? ?? '',
    important: (map['important'] as int? ?? 0) == 1,
    myDay: map['my_day'] as String?,
    dueAt: map['due_at'] as int?,
    dueHasTime: (map['due_has_time'] as int? ?? 0) == 1,
    recurrence: TodoRecurrence.tryParse(map['recurrence'] as String?),
    completedAt: map['completed_at'] as int?,
    sortOrder: (map['sort_order'] as num?)?.toDouble() ?? 0,
    steps: _decodeList(
      map['steps'] as String?,
      (e) => TodoStep.fromJson(e as Map<String, dynamic>),
    ),
    reminders: _decodeList(
      map['reminders'] as String?,
      (e) => TodoReminder.fromJson(e as Map<String, dynamic>),
    ),
    tags: _decodeList(map['tags'] as String?, (v) => v as String),
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
    deleted: (map['deleted'] as int? ?? 0) == 1,
  );

  factory TodoTask.fromJson(
    String shortId,
    Map<String, dynamic> json, {
    required int updatedAt,
    bool deleted = false,
  }) => TodoTask(
    shortId: shortId,
    listId: json['listId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    note: json['note'] as String? ?? '',
    important: json['important'] as bool? ?? false,
    myDay: json['myDay'] as String?,
    dueAt: json['dueAt'] as int?,
    dueHasTime: json['dueHasTime'] as bool? ?? false,
    recurrence: TodoRecurrence.tryParse(json['recurrence'] as String?),
    completedAt: json['completedAt'] as int?,
    sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0,
    steps: [
      for (final s in json['steps'] as List? ?? const [])
        if (s is Map<String, dynamic>) TodoStep.fromJson(s),
    ],
    reminders: [
      for (final r in json['reminders'] as List? ?? const [])
        if (r is Map<String, dynamic>) TodoReminder.fromJson(r),
    ],
    tags: [
      for (final t in json['tags'] as List? ?? const [])
        if (t is String) t,
    ],
    createdAt: json['createdAt'] as int? ?? updatedAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );

  static List<T> _decodeList<T>(String? raw, T Function(dynamic) parse) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <T>[];
      for (final e in decoded) {
        try {
          out.add(parse(e));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Map<String, Object?> toRow() => {
    'short_id': shortId,
    'list_id': listId,
    'title': title,
    'note': note,
    'important': important ? 1 : 0,
    'my_day': myDay,
    'due_at': dueAt,
    'due_has_time': dueHasTime ? 1 : 0,
    'recurrence': recurrence?.encode(),
    'completed_at': completedAt,
    'sort_order': sortOrder,
    'steps': jsonEncode([for (final s in steps) s.toJson()]),
    'reminders': jsonEncode([for (final r in reminders) r.toJson()]),
    'tags': jsonEncode(tags),
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted': deleted ? 1 : 0,
  };

  Map<String, dynamic> toJson() => {
    'listId': listId,
    'title': title,
    'note': note,
    'important': important,
    'myDay': myDay,
    'dueAt': dueAt,
    'dueHasTime': dueHasTime,
    'recurrence': recurrence?.encode(),
    'completedAt': completedAt,
    'sortOrder': sortOrder,
    'steps': [for (final s in steps) s.toJson()],
    'reminders': [for (final r in reminders) r.toJson()],
    'tags': tags,
    'createdAt': createdAt,
  };

  TodoTask copyWith({
    String? shortId,
    String? listId,
    String? title,
    String? note,
    bool? important,
    String? Function()? myDay,
    int? Function()? dueAt,
    bool? dueHasTime,
    TodoRecurrence? Function()? recurrence,
    int? Function()? completedAt,
    double? sortOrder,
    List<TodoStep>? steps,
    List<TodoReminder>? reminders,
    List<String>? tags,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
  }) => TodoTask(
    shortId: shortId ?? this.shortId,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    note: note ?? this.note,
    important: important ?? this.important,
    myDay: myDay != null ? myDay() : this.myDay,
    dueAt: dueAt != null ? dueAt() : this.dueAt,
    dueHasTime: dueHasTime ?? this.dueHasTime,
    recurrence: recurrence != null ? recurrence() : this.recurrence,
    completedAt: completedAt != null ? completedAt() : this.completedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    steps: steps ?? this.steps,
    reminders: reminders ?? this.reminders,
    tags: tags ?? this.tags,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
}

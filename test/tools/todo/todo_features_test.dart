import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations_en.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/models/todo_filter.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_db_helper.dart';
import 'package:tool_lab/tools/todo/todo_notify_settings.dart';
import 'package:tool_lab/tools/todo/todo_operations.dart';
import 'package:tool_lab/tools/todo/todo_publisher.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';
import 'package:tool_lab/tools/todo/todo_view.dart';

TodoTask _task(
  String id, {
  DateTime? due,
  DateTime? start,
  bool important = false,
  List<String> tags = const [],
  String listId = 'L1',
  List<TodoReminder> reminders = const [],
  int? completedAt,
}) => TodoTask(
  shortId: id,
  listId: listId,
  title: 'Task $id',
  important: important,
  dueAt: due?.millisecondsSinceEpoch,
  startAt: start?.millisecondsSinceEpoch,
  sortOrder: 0,
  tags: tags,
  reminders: reminders,
  completedAt: completedAt,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  // Thursday.
  final now = DateTime(2026, 11, 19, 12);
  final today = DateTime(2026, 11, 19);
  final l10n = AppLocalizationsEn();

  group('start date', () {
    test('hides the task until that day', () {
      final task = _task('a', start: DateTime(2026, 11, 20));
      expect(task.isDeferred(now), isTrue);
      expect(task.isDeferred(DateTime(2026, 11, 20, 0, 1)), isFalse);
    });

    test('moving the due date before the start date clears it', () {
      final task = _task(
        'a',
        due: DateTime(2026, 11, 30),
        start: DateTime(2026, 11, 25),
      );
      final moved = TodoOperations.moveDue(task, today, now: now);
      expect(moved.startAt, isNull);
      final later = TodoOperations.moveDue(
        task,
        DateTime(2026, 12, 1),
        now: now,
      );
      expect(later.startAt, task.startAt);
    });

    test('a recurring task moves its start date with the due date', () {
      final task = _task(
        'a',
        due: DateTime(2026, 11, 19),
        start: DateTime(2026, 11, 17),
      ).copyWith(recurrence: () => TodoRecurrence.weekly);
      final advanced = TodoOperations.complete(
        task,
        now: now,
        newId: () => 'h',
      ).firstWhere((t) => t.shortId == 'a');
      expect(advanced.start, DateTime(2026, 11, 24));
    });
  });

  group('views and filters', () {
    final overdue = _task('o', due: DateTime(2026, 11, 18));
    final sunday = _task('s', due: DateTime(2026, 11, 22));
    final monday = _task('m', due: DateTime(2026, 11, 23));
    final undated = _task('u', tags: const ['Home'], important: true);

    test('this week runs to Sunday and includes overdue', () {
      final view = TodoView.smart(TodoSmartList.thisWeek);
      expect(view.matches(overdue, now), isTrue);
      expect(view.matches(sunday, now), isTrue);
      expect(view.matches(monday, now), isFalse);
      expect(view.matches(undated, now), isFalse);
    });

    test('no date matches undated tasks only', () {
      final view = TodoView.smart(TodoSmartList.noDate);
      expect(view.matches(undated, now), isTrue);
      expect(view.matches(sunday, now), isFalse);
    });

    test('a saved filter combines its conditions', () {
      const filter = TodoFilter(
        id: 'F',
        name: 'Home',
        tag: 'home',
        importantOnly: true,
        due: TodoFilterDue.noDate,
      );
      const view = TodoView.filter('F');
      expect(view.matches(undated, now, {'F': filter}), isTrue);
      expect(
        view.matches(undated.copyWith(important: false), now, {'F': filter}),
        isFalse,
      );
      expect(view.matches(undated, now), isFalse);
      expect(TodoView.fromWidgetKey(view.widgetKey), view);
    });

    test('filters round-trip through JSON', () {
      const filter = TodoFilter(
        id: 'F',
        name: 'Soon',
        listId: 'L1',
        due: TodoFilterDue.next7Days,
      );
      final decoded = TodoFilter.decode(
        '[{"id":"F","name":"Soon","listId":"L1","due":"next7Days"}]',
      ).single;
      expect(decoded.toJson(), filter.toJson());
    });

    test('the widget snapshot hides deferred tasks and lists filters', () {
      final hidden = _task('h', start: DateTime(2026, 11, 25));
      final snapshot = TodoPublisher.buildWidgetSnapshot(
        [undated, hidden],
        const [],
        l10n,
        filters: const [TodoFilter(id: 'F', name: 'Everything')],
        now: now,
      );
      final lists = snapshot['lists']! as List;
      final all = lists.firstWhere((l) => (l as Map)['id'] == 'smart:all');
      expect((all as Map)['openCount'], 1);
      final filter = lists.last as Map;
      expect(filter['id'], 'filter:F');
      expect(filter['openCount'], 1);
    });
  });

  group('reminder repeat and summary', () {
    final reminder = TodoReminder(
      at: DateTime(2026, 11, 19, 15).millisecondsSinceEpoch,
    );
    final lists = <String, TodoList>{};

    test('repeat applies to important tasks unless set for all', () {
      final tasks = [
        _task('i', important: true, reminders: [reminder]),
        _task('n', reminders: [reminder]),
      ];
      const settings = TodoNotifySettings(repeatMinutes: 15);
      final entries = TodoPublisher.buildEntries(
        tasks,
        lists,
        l10n,
        now: now,
        settings: settings,
        repeats: true,
      );
      expect({for (final e in entries) e.taskId: e.repeat}, {'i': 15, 'n': 0});
      final all = TodoPublisher.buildEntries(
        tasks,
        lists,
        l10n,
        now: now,
        settings: settings.copyWith(repeatAll: true),
        repeats: true,
      );
      expect(all.every((e) => e.repeat == 15), isTrue);
    });

    test('summary counts due, overdue and My Day per day', () {
      final tasks = [
        _task('o', due: DateTime(2026, 11, 18)),
        _task('d', due: DateTime(2026, 11, 20)),
        _task('m').copyWith(myDay: () => TodoTask.dayKey(now)),
        _task('x', due: DateTime(2026, 11, 20), completedAt: 1),
      ];
      const settings = TodoNotifySettings(
        digestEnabled: true,
        digestMinutes: 13 * 60,
      );
      final digests = TodoPublisher.buildDigests(
        tasks,
        l10n,
        settings,
        from: now,
        to: now.add(const Duration(days: 2)),
        now: now,
      );
      expect(digests.map((d) => d.time), [
        DateTime(2026, 11, 19, 13),
        DateTime(2026, 11, 20, 13),
      ]);
      expect(digests.first.body, startsWith('1 overdue · 1 in My Day'));
      expect(digests.last.body, startsWith('1 due today · 1 overdue'));
      expect(digests.every((d) => d.isDigest), isTrue);
      expect(
        TodoPublisher.buildDigests(
          tasks,
          l10n,
          const TodoNotifySettings(),
          from: now,
          to: now.add(const Duration(days: 2)),
        ),
        isEmpty,
      );
    });
  });

  group('trash and cleanup', () {
    final db = TodoDbHelper.instance;

    test('deleted tasks can be listed and removed again', () async {
      final task = _task('t1', due: today);
      await db.addToTrash([task], now.millisecondsSinceEpoch);
      final trash = await db.getTrash();
      expect(trash.single.task.shortId, 't1');
      expect(trash.single.task.dueAt, task.dueAt);
      expect(trash.single.deletedTime, now);
      await db.removeFromTrash(ids: ['t1']);
      expect(await db.getTrash(), isEmpty);
    });

    test('cleanup deletes old completed tasks and expires trash', () async {
      final old = now.subtract(const Duration(days: 100));
      await db.upsertTasks([
        _task('old', completedAt: old.millisecondsSinceEpoch),
        _task(
          'recent',
          completedAt: now
              .subtract(const Duration(days: 5))
              .millisecondsSinceEpoch,
        ),
        _task('open'),
      ]);
      await db.addToTrash([_task('gone')], old.millisecondsSinceEpoch);
      expect(await TodoOperations.cleanup(0, now: now), isFalse);
      expect(await db.getTrash(), isEmpty);
      expect(await TodoOperations.cleanup(90, now: now), isTrue);
      final ids = (await db.getTasks()).map((t) => t.shortId).toSet();
      expect(ids, containsAll(['recent', 'open']));
      expect(ids, isNot(contains('old')));
      expect((await db.getTask('old'))!.deleted, isTrue);
    });
  });
}

extension on TodoAlarmEntry {
  DateTime get time => DateTime.fromMillisecondsSinceEpoch(at);
}

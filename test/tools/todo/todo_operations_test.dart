import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tool_lab/l10n/app_localizations_en.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_operations.dart';
import 'package:tool_lab/tools/todo/todo_publisher.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';
import 'package:tool_lab/tools/todo/todo_sort.dart';

TodoTask _task({
  TodoRecurrence? recurrence,
  DateTime? due,
  List<TodoReminder> reminders = const [],
  List<TodoStep> steps = const [],
}) => TodoTask(
  shortId: 'T1',
  listId: 'L1',
  title: 'Water plants',
  dueAt: due?.millisecondsSinceEpoch,
  dueHasTime: true,
  recurrence: recurrence,
  sortOrder: 0,
  reminders: reminders,
  steps: steps,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final now = DateTime(2026, 11, 19, 12);
  var ids = 0;
  String newId() => 'N${ids++}';

  group('TodoOperations.complete', () {
    test('plain task is just completed', () {
      final result = TodoOperations.complete(_task(), now: now, newId: newId);
      expect(result, hasLength(1));
      expect(result.single.completed, isTrue);
    });

    test('recurring task keeps history and advances due, reminders, steps', () {
      final due = DateTime(2026, 11, 19, 18);
      final task = _task(
        recurrence: TodoRecurrence.daily,
        due: due,
        reminders: [
          TodoReminder(
            at: due.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
        ],
        steps: const [TodoStep(id: 's', title: 'a', done: true)],
      );
      final result = TodoOperations.complete(task, now: now, newId: newId);
      expect(result, hasLength(2));
      final history = result.firstWhere((t) => t.shortId != 'T1');
      final advanced = result.firstWhere((t) => t.shortId == 'T1');
      expect(history.completed, isTrue);
      expect(history.recurrence, isNull);
      expect(advanced.completed, isFalse);
      expect(advanced.due, DateTime(2026, 11, 20, 18));
      expect(advanced.reminders.single.time, DateTime(2026, 11, 20, 17));
      expect(advanced.steps.single.done, isFalse);
    });

    test('ended series completes for good', () {
      final due = DateTime(2026, 11, 19, 18);
      final task = _task(
        recurrence: TodoRecurrence(
          freq: RecurrenceFreq.daily,
          until: DateTime(2026, 11, 19),
        ),
        due: due,
      );
      final result = TodoOperations.complete(task, now: now, newId: newId);
      expect(result.single.completed, isTrue);
    });

    test('rule from completion counts from the day it is done', () {
      final task = _task(
        recurrence: const TodoRecurrence(
          freq: RecurrenceFreq.weekly,
          fromCompletion: true,
        ),
        due: DateTime(2026, 11, 10, 8),
      );
      final result = TodoOperations.complete(task, now: now, newId: newId);
      final advanced = result.firstWhere((t) => t.shortId == 'T1');
      expect(advanced.due, DateTime(2026, 11, 26, 8));
    });
  });

  group('TodoOperations.moveDue', () {
    test('keeps the time and shifts reminders by whole days', () {
      final due = DateTime(2026, 11, 18, 18);
      final task = _task(
        due: due,
        reminders: [
          TodoReminder(at: DateTime(2026, 11, 18, 9).millisecondsSinceEpoch),
        ],
      );
      final moved = TodoOperations.moveDue(
        task,
        DateTime(2026, 11, 20),
        now: now,
      );
      expect(moved.due, DateTime(2026, 11, 20, 18));
      expect(moved.dueHasTime, isTrue);
      expect(moved.reminders.single.time, DateTime(2026, 11, 20, 9));
    });

    test('a time already past today becomes all-day', () {
      final task = _task(due: DateTime(2026, 11, 17, 8));
      final moved = TodoOperations.moveDue(
        task,
        DateTime(2026, 11, 19),
        now: now,
      );
      expect(moved.due, DateTime(2026, 11, 19));
      expect(moved.dueHasTime, isFalse);
      expect(moved.isOverdue(now), isFalse);
    });

    test('leaves My Day when moved to another day', () {
      final task = _task(
        due: DateTime(2026, 11, 19, 18),
      ).copyWith(myDay: () => TodoTask.dayKey(now));
      final moved = TodoOperations.moveDue(
        task,
        DateTime(2026, 11, 20),
        now: now,
      );
      expect(moved.myDay, isNull);
    });
  });

  group('TodoPublisher', () {
    final l10n = AppLocalizationsEn();
    final lists = {
      'L1': const TodoList(
        shortId: 'L1',
        name: 'Home',
        color: 0xFF66BB6A,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
      ),
    };

    test('recurring reminder fires on every occurrence in the window', () {
      final due = DateTime(2026, 11, 19, 18);
      final task = _task(
        recurrence: TodoRecurrence.daily,
        due: due,
        reminders: [
          TodoReminder(
            at: due
                .subtract(const Duration(minutes: 30))
                .millisecondsSinceEpoch,
            alarm: true,
          ),
        ],
      );
      final entries = TodoPublisher.buildEntries(
        [task],
        lists,
        l10n,
        now: now,
        window: const Duration(days: 3),
      );
      expect(entries.map((e) => e.at), [
        DateTime(2026, 11, 19, 17, 30).millisecondsSinceEpoch,
        DateTime(2026, 11, 20, 17, 30).millisecondsSinceEpoch,
        DateTime(2026, 11, 21, 17, 30).millisecondsSinceEpoch,
      ]);
      expect(entries.first.alarm, isTrue);
      expect(entries.first.body, startsWith('Home'));
      expect(entries.first.color, 0xFF66BB6A);
    });

    test('past and completed reminders are left out', () {
      final past = _task(
        reminders: [
          TodoReminder(
            at: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
        ],
      );
      final done = _task(
        reminders: [
          TodoReminder(
            at: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
        ],
      ).copyWith(completedAt: () => 1);
      expect(
        TodoPublisher.buildEntries([past, done], lists, l10n, now: now),
        isEmpty,
      );
    });

    test('widget snapshot lists smart views first, then lists', () {
      final task = _task(due: now).copyWith(important: true);
      final snapshot = TodoPublisher.buildWidgetSnapshot(
        [task],
        lists.values.toList(),
        l10n,
        now: now,
      );
      final ids = [
        for (final l in snapshot['lists']! as List) (l as Map)['id'],
      ];
      expect(ids, [
        'smart:myDay',
        'smart:important',
        'smart:planned',
        'smart:thisWeek',
        'smart:noDate',
        'smart:all',
        'L1',
      ]);
      final important = (snapshot['lists']! as List)[1] as Map;
      expect(important['openCount'], 1);
    });

    test('widget snapshot follows the stored sort mode of a list', () {
      final a = _task().copyWith(shortId: 'A', title: 'Zebra', sortOrder: 0);
      final b = _task().copyWith(shortId: 'B', title: 'Apple', sortOrder: 1);
      List<Object?> order(Map<String, TodoSort> modes) {
        final snapshot = TodoPublisher.buildWidgetSnapshot(
          [a, b],
          lists.values.toList(),
          l10n,
          sortModes: modes,
          now: now,
        );
        final list = (snapshot['lists']! as List).last as Map;
        return [for (final t in list['tasks'] as List) (t as Map)['id']];
      }

      expect(order({}), ['A', 'B']);
      expect(order({'L1': TodoSort.alphabetical}), ['B', 'A']);
    });
  });
}

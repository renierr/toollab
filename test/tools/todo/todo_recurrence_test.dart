import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';

void main() {
  group('TodoRecurrence encode/parse', () {
    test('round-trips weekly with days, interval and until', () {
      final rule = TodoRecurrence(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        weekdays: const {1, 4},
        until: DateTime(2026, 12, 31),
      );
      expect(
        rule.encode(),
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;UNTIL=20261231',
      );
      expect(TodoRecurrence.tryParse(rule.encode()), rule);
    });

    test('round-trips monthly nth weekday', () {
      const rule = TodoRecurrence(
        freq: RecurrenceFreq.monthly,
        weekdays: {5},
        monthlyNth: -1,
      );
      expect(rule.encode(), 'FREQ=MONTHLY;BYDAY=-1FR');
      final parsed = TodoRecurrence.tryParse(rule.encode())!;
      expect(parsed.monthlyNth, -1);
      expect(parsed.weekdays, {5});
    });

    test('rejects garbage', () {
      expect(TodoRecurrence.tryParse('nonsense'), isNull);
      expect(TodoRecurrence.tryParse(''), isNull);
    });
  });

  group('TodoRecurrence occurrences', () {
    test('daily keeps the time of day', () {
      final start = DateTime(2026, 3, 1, 9, 30);
      final next = TodoRecurrence.daily.nextAfter(start, start);
      expect(next, DateTime(2026, 3, 2, 9, 30));
    });

    test('weekdays skip the weekend', () {
      final friday = DateTime(2026, 11, 20, 8);
      expect(
        TodoRecurrence.weekdaysOnly.nextAfter(friday, friday),
        DateTime(2026, 11, 23, 8),
      );
    });

    test('every 2 weeks on Mon and Thu', () {
      const rule = TodoRecurrence(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        weekdays: {1, 4},
      );
      final start = DateTime(2026, 11, 16);
      final dates = rule.occurrences(start).take(4).toList();
      expect(dates, [
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 19),
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 3),
      ]);
    });

    test('monthly on the 31st clamps to the month end', () {
      final start = DateTime(2026, 1, 31);
      final dates = TodoRecurrence.monthly.occurrences(start).take(3).toList();
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      ]);
    });

    test('monthly on the second Tuesday', () {
      const rule = TodoRecurrence(
        freq: RecurrenceFreq.monthly,
        weekdays: {2},
        monthlyNth: 2,
      );
      final start = DateTime(2026, 11, 10);
      expect(rule.nextAfter(start, start), DateTime(2026, 12, 8));
    });

    test('yearly on Feb 29 falls back to Feb 28', () {
      final start = DateTime(2028, 2, 29);
      expect(
        TodoRecurrence.yearly.nextAfter(start, start),
        DateTime(2029, 2, 28),
      );
    });

    test('until ends the series', () {
      final rule = TodoRecurrence(
        freq: RecurrenceFreq.daily,
        until: DateTime(2026, 3, 3),
      );
      final start = DateTime(2026, 3, 1, 10);
      expect(rule.occurrences(start).length, 3);
      expect(rule.nextAfter(start, DateTime(2026, 3, 3, 10)), isNull);
    });
  });
}

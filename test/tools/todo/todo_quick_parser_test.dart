import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/todo/todo_quick_parser.dart';
import 'package:tool_lab/tools/todo/todo_recurrence.dart';

void main() {
  // Thursday, 19 Nov 2026, 10:00.
  final now = DateTime(2026, 11, 19, 10);

  test('plain title has no extras', () {
    final d = TodoQuickParser.parse('Buy milk', now: now);
    expect(d.title, 'Buy milk');
    expect(d.hasExtras, isFalse);
  });

  test('tomorrow with time, tag and importance', () {
    final d = TodoQuickParser.parse(
      'Pay rent tomorrow 18:00 #home !',
      now: now,
    );
    expect(d.title, 'Pay rent');
    expect(d.due, DateTime(2026, 11, 20, 18));
    expect(d.hasTime, isTrue);
    expect(d.tags, ['home']);
    expect(d.important, isTrue);
  });

  test('German weekday and "um"', () {
    final d = TodoQuickParser.parse('Zahnarzt am Freitag um 9', now: now);
    expect(d.title, 'Zahnarzt');
    expect(d.due, DateTime(2026, 11, 20, 9));
  });

  test('time alone in the past moves to tomorrow', () {
    final d = TodoQuickParser.parse('Call Anna 8am', now: now);
    expect(d.title, 'Call Anna');
    expect(d.due, DateTime(2026, 11, 20, 8));
  });

  test('dotted date without year rolls into next year when past', () {
    final d = TodoQuickParser.parse('Renew passport 3.2.', now: now);
    expect(d.due, DateTime(2027, 2, 3));
    expect(d.hasTime, isFalse);
  });

  test('every monday sets weekly recurrence and the next Monday', () {
    final d = TodoQuickParser.parse('Gym every monday 7:00', now: now);
    expect(d.title, 'Gym');
    expect(d.recurrence?.freq, RecurrenceFreq.weekly);
    expect(d.recurrence?.weekdays, {1});
    expect(d.due, DateTime(2026, 11, 23, 7));
  });

  test('alle 2 wochen', () {
    final d = TodoQuickParser.parse('Bettwäsche alle 2 wochen', now: now);
    expect(d.title, 'Bettwäsche');
    expect(d.recurrence?.interval, 2);
    expect(d.recurrence?.freq, RecurrenceFreq.weekly);
    expect(d.due, DateTime(2026, 11, 19));
  });

  test('numbers inside the title stay', () {
    final d = TodoQuickParser.parse('Order 3 chairs', now: now);
    expect(d.title, 'Order 3 chairs');
    expect(d.due, isNull);
  });

  test('in 3 days', () {
    final d = TodoQuickParser.parse('Follow up in 3 days', now: now);
    expect(d.title, 'Follow up');
    expect(d.due, DateTime(2026, 11, 22));
  });
}

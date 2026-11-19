enum RecurrenceFreq { daily, weekly, monthly, yearly }

/// RRULE subset: `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;UNTIL=20261231`.
/// Monthly by weekday uses `BYDAY=2TU` / `BYDAY=-1FR`. `X-FROM=COMPLETION`
/// counts the interval from the day the task is completed.
class TodoRecurrence {
  final RecurrenceFreq freq;
  final int interval;

  /// ISO weekdays (1 = Monday) for weekly rules; empty = the start's weekday.
  final Set<int> weekdays;

  /// Monthly by "nth weekday" instead of by day of month: 1..4 or -1 (last).
  final int? monthlyNth;

  /// Inclusive last day, local date.
  final DateTime? until;

  final bool fromCompletion;

  const TodoRecurrence({
    required this.freq,
    this.interval = 1,
    this.weekdays = const {},
    this.monthlyNth,
    this.until,
    this.fromCompletion = false,
  });

  static const List<String> _dayCodes = [
    'MO',
    'TU',
    'WE',
    'TH',
    'FR',
    'SA',
    'SU',
  ];

  static const TodoRecurrence daily = TodoRecurrence(
    freq: RecurrenceFreq.daily,
  );
  static const TodoRecurrence weekdaysOnly = TodoRecurrence(
    freq: RecurrenceFreq.weekly,
    weekdays: {1, 2, 3, 4, 5},
  );
  static const TodoRecurrence weekly = TodoRecurrence(
    freq: RecurrenceFreq.weekly,
  );
  static const TodoRecurrence monthly = TodoRecurrence(
    freq: RecurrenceFreq.monthly,
  );
  static const TodoRecurrence yearly = TodoRecurrence(
    freq: RecurrenceFreq.yearly,
  );

  bool get isWeekdays =>
      freq == RecurrenceFreq.weekly &&
      interval == 1 &&
      weekdays.length == 5 &&
      weekdays.containsAll(const {1, 2, 3, 4, 5});

  String encode() {
    final parts = <String>[
      'FREQ=${freq.name.toUpperCase()}',
      if (interval != 1) 'INTERVAL=$interval',
    ];
    if (freq == RecurrenceFreq.weekly && weekdays.isNotEmpty) {
      final sorted = weekdays.toList()..sort();
      parts.add('BYDAY=${sorted.map((d) => _dayCodes[d - 1]).join(',')}');
    }
    if (freq == RecurrenceFreq.monthly && monthlyNth != null) {
      final day = weekdays.isEmpty ? 1 : weekdays.first;
      parts.add('BYDAY=$monthlyNth${_dayCodes[day - 1]}');
    }
    if (fromCompletion) parts.add('X-FROM=COMPLETION');
    final u = until;
    if (u != null) {
      parts.add(
        'UNTIL=${u.year.toString().padLeft(4, '0')}${u.month.toString().padLeft(2, '0')}${u.day.toString().padLeft(2, '0')}',
      );
    }
    return parts.join(';');
  }

  static TodoRecurrence? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final fields = <String, String>{};
      for (final part in raw.split(';')) {
        final i = part.indexOf('=');
        if (i <= 0) continue;
        fields[part.substring(0, i).trim().toUpperCase()] = part
            .substring(i + 1)
            .trim()
            .toUpperCase();
      }
      final freq = RecurrenceFreq.values.firstWhere(
        (f) => f.name.toUpperCase() == fields['FREQ'],
      );
      final interval = int.tryParse(fields['INTERVAL'] ?? '') ?? 1;
      final weekdays = <int>{};
      int? nth;
      final byDay = fields['BYDAY'];
      if (byDay != null && byDay.isNotEmpty) {
        for (final code in byDay.split(',')) {
          final match = RegExp(r'^(-?\d)?([A-Z]{2})$').firstMatch(code.trim());
          if (match == null) continue;
          final day = _dayCodes.indexOf(match.group(2)!) + 1;
          if (day == 0) continue;
          weekdays.add(day);
          if (match.group(1) != null) nth = int.parse(match.group(1)!);
        }
      }
      DateTime? until;
      final u = fields['UNTIL'];
      if (u != null && u.length >= 8) {
        until = DateTime(
          int.parse(u.substring(0, 4)),
          int.parse(u.substring(4, 6)),
          int.parse(u.substring(6, 8)),
        );
      }
      return TodoRecurrence(
        freq: freq,
        interval: interval < 1 ? 1 : interval,
        weekdays: weekdays,
        monthlyNth: freq == RecurrenceFreq.monthly ? nth : null,
        until: until,
        fromCompletion: fields['X-FROM'] == 'COMPLETION',
      );
    } catch (_) {
      return null;
    }
  }

  TodoRecurrence copyWith({
    RecurrenceFreq? freq,
    int? interval,
    Set<int>? weekdays,
    int? Function()? monthlyNth,
    DateTime? Function()? until,
    bool? fromCompletion,
  }) => TodoRecurrence(
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    monthlyNth: monthlyNth != null ? monthlyNth() : this.monthlyNth,
    until: until != null ? until() : this.until,
    fromCompletion: fromCompletion ?? this.fromCompletion,
  );

  /// Next due date of a task completed on [done]: one interval after that
  /// day, at [due]'s time of day. Null when the rule ended.
  DateTime? nextFromCompletion(DateTime due, DateTime done) {
    DateTime clamped(int year, int month) {
      final last = DateTime(year, month + 1, 0).day;
      return DateTime(
        year,
        month,
        done.day.clamp(1, last),
        due.hour,
        due.minute,
      );
    }

    final next = switch (freq) {
      RecurrenceFreq.daily => DateTime(
        done.year,
        done.month,
        done.day + interval,
        due.hour,
        due.minute,
      ),
      RecurrenceFreq.weekly => DateTime(
        done.year,
        done.month,
        done.day + 7 * interval,
        due.hour,
        due.minute,
      ),
      RecurrenceFreq.monthly => clamped(
        DateTime(done.year, done.month + interval).year,
        DateTime(done.year, done.month + interval).month,
      ),
      RecurrenceFreq.yearly => clamped(done.year + interval, done.month),
    };
    final u = until;
    if (u != null &&
        next.isAfter(DateTime(u.year, u.month, u.day, 23, 59, 59))) {
      return null;
    }
    return next;
  }

  /// Occurrences on or after [start], in order; [start] itself is the first
  /// when it matches the rule. Time of day is taken from [start].
  Iterable<DateTime> occurrences(DateTime start) sync* {
    final untilEnd = until == null
        ? null
        : DateTime(until!.year, until!.month, until!.day, 23, 59, 59);
    bool ended(DateTime d) => untilEnd != null && d.isAfter(untilEnd);
    DateTime at(int y, int m, int d) =>
        DateTime(y, m, d, start.hour, start.minute);

    switch (freq) {
      case RecurrenceFreq.daily:
        for (var k = 0; k < 100000; k++) {
          final d = at(start.year, start.month, start.day + k * interval);
          if (ended(d)) return;
          yield d;
        }
      case RecurrenceFreq.weekly:
        final days = (weekdays.isEmpty ? {start.weekday} : weekdays).toList()
          ..sort();
        final weekStart = DateTime(
          start.year,
          start.month,
          start.day - (start.weekday - 1),
        );
        for (var w = 0; w < 20000; w++) {
          for (final day in days) {
            final d = at(
              weekStart.year,
              weekStart.month,
              weekStart.day + w * 7 * interval + day - 1,
            );
            if (d.isBefore(start)) continue;
            if (ended(d)) return;
            yield d;
          }
        }
      case RecurrenceFreq.monthly:
        for (var k = 0; k < 10000; k++) {
          final first = DateTime(start.year, start.month + k * interval);
          final DateTime? d;
          if (monthlyNth != null) {
            final weekday = weekdays.isEmpty ? start.weekday : weekdays.first;
            d = _nthWeekday(first.year, first.month, weekday, monthlyNth!);
          } else {
            final last = DateTime(first.year, first.month + 1, 0).day;
            d = DateTime(first.year, first.month, start.day.clamp(1, last));
          }
          if (d == null) continue;
          final full = at(d.year, d.month, d.day);
          if (full.isBefore(start)) continue;
          if (ended(full)) return;
          yield full;
        }
      case RecurrenceFreq.yearly:
        for (var k = 0; k < 1000; k++) {
          final year = start.year + k * interval;
          final last = DateTime(year, start.month + 1, 0).day;
          final d = at(year, start.month, start.day.clamp(1, last));
          if (ended(d)) return;
          yield d;
        }
    }
  }

  /// First occurrence strictly after [after], or null when the rule ended.
  DateTime? nextAfter(DateTime start, DateTime after) {
    for (final d in occurrences(start)) {
      if (d.isAfter(after)) return d;
    }
    return null;
  }

  static DateTime? _nthWeekday(int year, int month, int weekday, int nth) {
    if (nth > 0) {
      final first = DateTime(year, month);
      final offset = (weekday - first.weekday + 7) % 7;
      final day = 1 + offset + (nth - 1) * 7;
      if (day > DateTime(year, month + 1, 0).day) return null;
      return DateTime(year, month, day);
    }
    final lastDay = DateTime(year, month + 1, 0);
    final offset = (lastDay.weekday - weekday + 7) % 7;
    return DateTime(year, month, lastDay.day - offset);
  }

  @override
  bool operator ==(Object other) =>
      other is TodoRecurrence && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

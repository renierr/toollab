import 'package:tool_lab/tools/todo/todo_recurrence.dart';

class TodoQuickDraft {
  final String title;
  final DateTime? due;
  final bool hasTime;
  final bool important;
  final List<String> tags;
  final TodoRecurrence? recurrence;

  const TodoQuickDraft({
    required this.title,
    this.due,
    this.hasTime = false,
    this.important = false,
    this.tags = const [],
    this.recurrence,
  });

  bool get hasExtras =>
      due != null || important || tags.isNotEmpty || recurrence != null;
}

/// Parses quick-add text, English and German:
/// `Pay rent tomorrow 18:00 #home !`, `Gym jeden Montag um 7`, `Call mom 24.12.`
class TodoQuickParser {
  TodoQuickParser._();

  static const Map<String, int> _weekdays = {
    'mon': 1,
    'monday': 1,
    'mo': 1,
    'montag': 1,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'di': 2,
    'dienstag': 2,
    'wed': 3,
    'wednesday': 3,
    'mi': 3,
    'mittwoch': 3,
    'thu': 4,
    'thur': 4,
    'thursday': 4,
    'do': 4,
    'donnerstag': 4,
    'fri': 5,
    'friday': 5,
    'fr': 5,
    'freitag': 5,
    'sat': 6,
    'saturday': 6,
    'sa': 6,
    'samstag': 6,
    'sun': 7,
    'sunday': 7,
    'so': 7,
    'sonntag': 7,
  };

  // Two-letter German abbreviations collide with words ("so", "do"); they
  // only count after "every"/"jeden" or "on"/"am".
  static const Set<String> _ambiguous = {
    'mo',
    'di',
    'mi',
    'do',
    'fr',
    'sa',
    'so',
  };

  static TodoQuickDraft parse(String input, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final tokens = input.trim().split(RegExp(r'\s+'));
    final keep = <String>[];
    final tags = <String>[];
    var important = false;
    DateTime? date;
    int? hour;
    int? minute;
    TodoRecurrence? recurrence;

    String lower(int i) => i < tokens.length
        ? tokens[i].toLowerCase().replaceAll(RegExp(r'[,.]$'), '')
        : '';

    for (var i = 0; i < tokens.length; i++) {
      final raw = tokens[i];
      final t = lower(i);
      if (raw.isEmpty) continue;

      if (raw.startsWith('#') && raw.length > 1) {
        tags.add(raw.substring(1));
        continue;
      }
      if (RegExp(r'^!+$').hasMatch(raw)) {
        important = true;
        continue;
      }

      // Recurrence.
      if (const {'daily', 'täglich', 'taeglich'}.contains(t)) {
        recurrence = TodoRecurrence.daily;
        continue;
      }
      if (const {'weekly', 'wöchentlich', 'woechentlich'}.contains(t)) {
        recurrence = TodoRecurrence.weekly;
        continue;
      }
      if (const {'monthly', 'monatlich'}.contains(t)) {
        recurrence = TodoRecurrence.monthly;
        continue;
      }
      if (const {'yearly', 'annually', 'jährlich', 'jaehrlich'}.contains(t)) {
        recurrence = TodoRecurrence.yearly;
        continue;
      }
      if (const {'weekdays', 'werktags'}.contains(t)) {
        recurrence = TodoRecurrence.weekdaysOnly;
        continue;
      }
      if (const {'every', 'jeden', 'jede', 'jedes', 'alle'}.contains(t) &&
          i + 1 < tokens.length) {
        final next = lower(i + 1);
        final weekday = _weekdays[next];
        if (weekday != null) {
          recurrence = TodoRecurrence(
            freq: RecurrenceFreq.weekly,
            weekdays: {weekday},
          );
          date ??= _nextWeekday(today, weekday, allowToday: true);
          i++;
          continue;
        }
        final unit = _unit(next);
        if (unit != null) {
          recurrence = TodoRecurrence(freq: unit);
          i++;
          continue;
        }
        final count = int.tryParse(next);
        final unit2 = _unit(lower(i + 2));
        if (count != null && count > 0 && unit2 != null) {
          recurrence = TodoRecurrence(freq: unit2, interval: count);
          i += 2;
          continue;
        }
      }

      // Relative days.
      if (const {'today', 'heute', 'tod'}.contains(t)) {
        date = today;
        continue;
      }
      if (const {'tomorrow', 'morgen', 'tmr', 'tom'}.contains(t)) {
        date = today.add(const Duration(days: 1));
        continue;
      }
      if (const {'übermorgen', 'uebermorgen'}.contains(t)) {
        date = today.add(const Duration(days: 2));
        continue;
      }
      if (const {
            'next',
            'nächste',
            'nächsten',
            'naechste',
            'nächster',
          }.contains(t) &&
          const {'week', 'woche'}.contains(lower(i + 1))) {
        date = _nextWeekday(today, 1, allowToday: false);
        i++;
        continue;
      }
      if (const {'in'}.contains(t)) {
        final count = int.tryParse(lower(i + 1));
        final unit = lower(i + 2);
        if (count != null) {
          if (const {'day', 'days', 'tag', 'tagen', 'tage'}.contains(unit)) {
            date = today.add(Duration(days: count));
            i += 2;
            continue;
          }
          if (const {'week', 'weeks', 'woche', 'wochen'}.contains(unit)) {
            date = today.add(Duration(days: 7 * count));
            i += 2;
            continue;
          }
        }
      }

      // Weekday names ("on friday", "am Freitag", "friday").
      final prefixOn = const {'on', 'am'}.contains(t);
      final candidate = prefixOn ? lower(i + 1) : t;
      final weekday = _weekdays[candidate];
      if (weekday != null && (prefixOn || !_ambiguous.contains(candidate))) {
        date = _nextWeekday(today, weekday, allowToday: false);
        if (prefixOn) i++;
        continue;
      }

      // Explicit dates.
      final parsedDate = _parseDate(t, today);
      if (parsedDate != null) {
        date = parsedDate;
        continue;
      }

      // Times: "18:00", "9am", "at 9", "um 9", "18 uhr".
      final atPrefix = const {'at', 'um', '@'}.contains(t);
      final timeToken = atPrefix ? lower(i + 1) : t;
      final time = _parseTime(
        timeToken,
        requireMarker: !atPrefix,
        nextToken: lower(atPrefix ? i + 2 : i + 1),
      );
      if (time != null) {
        hour = time.$1;
        minute = time.$2;
        if (atPrefix) i++;
        if (time.$3) i++;
        continue;
      }

      keep.add(raw);
    }

    final hasTime = hour != null;
    if (hasTime && date == null) {
      final candidate = DateTime(
        today.year,
        today.month,
        today.day,
        hour,
        minute!,
      );
      date = candidate.isBefore(n) ? today.add(const Duration(days: 1)) : today;
    }
    if (recurrence != null && date == null) date = today;
    final due = date == null
        ? null
        : DateTime(date.year, date.month, date.day, hour ?? 0, minute ?? 0);

    var title = keep.join(' ').trim();
    if (title.isEmpty) title = input.trim();
    return TodoQuickDraft(
      title: title,
      due: due,
      hasTime: hasTime,
      important: important,
      tags: tags,
      recurrence: recurrence,
    );
  }

  static RecurrenceFreq? _unit(String t) => switch (t) {
    'day' || 'days' || 'tag' || 'tage' => RecurrenceFreq.daily,
    'week' || 'weeks' || 'woche' || 'wochen' => RecurrenceFreq.weekly,
    'month' || 'months' || 'monat' || 'monate' => RecurrenceFreq.monthly,
    'year' || 'years' || 'jahr' || 'jahre' => RecurrenceFreq.yearly,
    _ => null,
  };

  static DateTime _nextWeekday(
    DateTime today,
    int weekday, {
    required bool allowToday,
  }) {
    var diff = (weekday - today.weekday + 7) % 7;
    if (diff == 0 && !allowToday) diff = 7;
    return today.add(Duration(days: diff));
  }

  static DateTime? _parseDate(String t, DateTime today) {
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
    if (iso != null) {
      return _valid(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final dotted = RegExp(r'^(\d{1,2})\.(\d{1,2})\.?(\d{2,4})?$').firstMatch(t);
    if (dotted != null) {
      final day = int.parse(dotted.group(1)!);
      final month = int.parse(dotted.group(2)!);
      return _withYear(day, month, dotted.group(3), today);
    }
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$').firstMatch(t);
    if (slash != null) {
      final month = int.parse(slash.group(1)!);
      final day = int.parse(slash.group(2)!);
      return _withYear(day, month, slash.group(3), today);
    }
    return null;
  }

  static DateTime? _withYear(int day, int month, String? year, DateTime today) {
    if (year != null) {
      var y = int.parse(year);
      if (y < 100) y += 2000;
      return _valid(y, month, day);
    }
    final thisYear = _valid(today.year, month, day);
    if (thisYear == null) return null;
    return thisYear.isBefore(today)
        ? _valid(today.year + 1, month, day)
        : thisYear;
  }

  static DateTime? _valid(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > DateTime(y, m + 1, 0).day) return null;
    return DateTime(y, m, d);
  }

  /// (hour, minute, consumedNextToken).
  static (int, int, bool)? _parseTime(
    String t, {
    required bool requireMarker,
    required String nextToken,
  }) {
    final colon = RegExp(r'^(\d{1,2})[:.](\d{2})(am|pm|h)?$').firstMatch(t);
    if (colon != null) {
      if (t.contains('.') && colon.group(3) == null && requireMarker) {
        // "12.30" could be a date fragment; only with a marker.
        return null;
      }
      return _hm(
        int.parse(colon.group(1)!),
        int.parse(colon.group(2)!),
        colon.group(3),
        false,
      );
    }
    final ampm = RegExp(r'^(\d{1,2})(am|pm|h)$').firstMatch(t);
    if (ampm != null) {
      return _hm(int.parse(ampm.group(1)!), 0, ampm.group(2), false);
    }
    final bare = RegExp(r'^(\d{1,2})$').firstMatch(t);
    if (bare != null) {
      final h = int.parse(bare.group(1)!);
      if (const {'uhr', 'h', "o'clock"}.contains(nextToken)) {
        return _hm(h, 0, null, true);
      }
      if (const {'am', 'pm'}.contains(nextToken)) {
        return _hm(h, 0, nextToken, true);
      }
      if (!requireMarker) return _hm(h, 0, null, false);
    }
    return null;
  }

  static (int, int, bool)? _hm(int h, int m, String? marker, bool consumed) {
    if (marker == 'pm' && h < 12) h += 12;
    if (marker == 'am' && h == 12) h = 0;
    if (h > 23 || m > 59) return null;
    return (h, m, consumed);
  }
}

import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Bucket key equal iff two dates share the same [fileManagerDateGroup]
/// label. Integer comparison lets consecutive-run grouping run without
/// building a DateFormat per entry; labels are formatted once per group.
(int, int)? fileManagerDateBucket(DateTime? date, DateTime now) {
  if (date == null) return null;
  final day = DateTime(date.year, date.month, date.day);
  final days = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (days >= 0 && days < 7) return (0, day.millisecondsSinceEpoch);
  return (1, date.year * 12 + date.month);
}

/// Labels a file's date with the coarsest bucket that still tells the user
/// something: exact days for the last week, months within the current year,
/// month and year before that.
String fileManagerDateGroup(
  DateTime date,
  DateTime now,
  String locale,
  AppLocalizations l10n,
) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l10n.fileManagerDateToday;
  if (days == 1) return l10n.fileManagerDateYesterday;
  if (days > 1 && days < 7) return DateFormat.MMMEd(locale).format(date);
  if (date.year == now.year) return DateFormat.MMMM(locale).format(date);
  return DateFormat.yMMMM(locale).format(date);
}

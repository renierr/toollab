import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

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

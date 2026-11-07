import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

String newsRelativeTimeFor(
  AppLocalizations l10n,
  String locale,
  int milliseconds,
) {
  if (milliseconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final diff = DateTime.now().difference(date);
  if (diff.isNegative || diff.inMinutes < 1) return l10n.newsTimeJustNow;
  if (diff.inMinutes < 60) return l10n.newsTimeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.newsTimeHoursAgo(diff.inHours);
  if (diff.inDays == 1) return l10n.newsTimeYesterday;
  if (diff.inDays < 7) return l10n.newsTimeDaysAgo(diff.inDays);
  return DateFormat.MMMd(locale).format(date);
}

String newsDayLabel(
  AppLocalizations l10n,
  String locale,
  DateTime date,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return l10n.newsToday;
  if (difference == 1) return l10n.newsYesterday;
  return DateFormat.MMMMd(locale).format(date);
}

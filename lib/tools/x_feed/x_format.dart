import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class XFormat {
  XFormat._();

  static String relativeTime(
    DateTime? time,
    AppLocalizations l10n,
    String locale, {
    DateTime? now,
  }) {
    if (time == null) return '';
    final current = now ?? DateTime.now();
    final local = time.toLocal();
    final age = current.difference(local);
    if (age.inMinutes < 1) return l10n.xFeedNow;
    if (age.inHours < 1) return l10n.xFeedMinutesShort(age.inMinutes);
    if (age.inDays < 1) return l10n.xFeedHoursShort(age.inHours);
    if (local.year == current.year) {
      return DateFormat.MMMd(locale).format(local);
    }
    return DateFormat.yMMMd(locale).format(local);
  }

  static String fullTime(DateTime? time, String locale) {
    if (time == null) return '';
    return DateFormat.yMMMd(locale).add_Hm().format(time.toLocal());
  }

  /// `m:ss`, or `h:mm:ss` from an hour on.
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  static String count(int value, String locale) =>
      value <= 0 ? '' : NumberFormat.compact(locale: locale).format(value);
}

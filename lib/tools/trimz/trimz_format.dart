import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

String trimzCompact(int value, String locale) =>
    NumberFormat.compact(locale: locale).format(value);

/// "280 episodes · 690K views", leaving out what is unknown.
String trimzSeriesStats(
  AppLocalizations l10n, {
  required int episodes,
  required int views,
  required String locale,
}) => [
  if (episodes > 0) l10n.trimzEpisodeCount(episodes),
  if (views > 0) l10n.trimzViews(trimzCompact(views, locale)),
].join(' · ');

String trimzRuntime(AppLocalizations l10n, Duration runtime) {
  final minutes = runtime.inMinutes;
  if (minutes < 60) return l10n.trimzRuntimeMinutes(minutes < 1 ? 1 : minutes);
  return l10n.trimzRuntimeHours(minutes ~/ 60, minutes % 60);
}

/// "0:57" or "1:02:03".
String trimzClock(Duration d) {
  final seconds = d.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

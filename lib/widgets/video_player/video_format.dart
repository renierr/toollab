import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// `m:ss`, or `h:mm:ss` from an hour on.
String formatVideoTime(Duration d) {
  final minutes = d.inMinutes;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$seconds';
  final mm = (minutes % 60).toString().padLeft(2, '0');
  return '${d.inHours}:$mm:$seconds';
}

/// `1.5×`; [normal] uses the localized word for 1×.
String formatVideoSpeed(
  double speed, {
  required AppLocalizations l10n,
  required String locale,
  bool normal = true,
}) {
  if (normal && speed == 1) return l10n.videoPlayerSpeedNormal;
  return '${NumberFormat('0.##', locale).format(speed)}×';
}

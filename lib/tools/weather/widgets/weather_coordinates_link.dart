import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Small latitude/longitude text that opens the spot in OpenStreetMap, so
/// places with the same name can be told apart.
class WeatherCoordinatesLink extends StatelessWidget {
  const WeatherCoordinatesLink({
    super.key,
    required this.latitude,
    required this.longitude,
    this.color,
  });

  final double latitude;
  final double longitude;
  final Color? color;

  static String format(String locale, double lat, double lon) {
    final n = NumberFormat('0.000', locale);
    return '${n.format(lat.abs())}° ${lat < 0 ? 'S' : 'N'}, '
        '${n.format(lon.abs())}° ${lon < 0 ? 'W' : 'E'}';
  }

  static Uri mapUri(double lat, double lon) => Uri.https(
    'www.openstreetmap.org',
    '/',
    {'mlat': '$lat', 'mlon': '$lon'},
  ).replace(fragment: 'map=12/$lat/$lon');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.labelSmall?.copyWith(color: ink);
    return Tooltip(
      message: l10n.weatherOpenMap,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => launchUrl(
          mapUri(latitude, longitude),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  format(l10n.localeName, latitude, longitude),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.map_outlined, size: 14, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

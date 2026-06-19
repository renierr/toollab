import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

class MapLinks extends StatelessWidget {
  final double latitude;
  final double longitude;

  const MapLinks({super.key, required this.latitude, required this.longitude});

  static Uri googleMapsUri(double lat, double lon) =>
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');

  static Uri openStreetMapUri(double lat, double lon) => Uri.parse(
    'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=16/$lat/$lon',
  );

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final buttons = [
      _MapButton(
        icon: Icons.map_outlined,
        label: l10n.gpsStoreOpenGoogleMaps,
        onTap: () => _open(googleMapsUri(latitude, longitude)),
        filled: true,
        color: theme.colorScheme.primary,
      ),
      _MapButton(
        icon: Icons.public,
        label: l10n.gpsStoreOpenOsm,
        onTap: () => _open(openStreetMapUri(latitude, longitude)),
        filled: false,
        color: theme.colorScheme.primary,
      ),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color color;

  const _MapButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          shape: shape,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: shape,
      ),
    );
  }
}

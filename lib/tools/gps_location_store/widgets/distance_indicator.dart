import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../location_capture_service.dart';
import '../location_format.dart';

/// Shows the distance and approximate compass direction from the live
/// [from] position to a target coordinate.
class DistanceIndicator extends StatelessWidget {
  final LocationFix from;
  final double targetLat;
  final double targetLon;

  const DistanceIndicator({
    super.key,
    required this.from,
    required this.targetLat,
    required this.targetLon,
  });

  String _compass(AppLocalizations l10n, int index) {
    switch (index) {
      case 1:
        return l10n.gpsStoreCompassNE;
      case 2:
        return l10n.gpsStoreCompassE;
      case 3:
        return l10n.gpsStoreCompassSE;
      case 4:
        return l10n.gpsStoreCompassS;
      case 5:
        return l10n.gpsStoreCompassSW;
      case 6:
        return l10n.gpsStoreCompassW;
      case 7:
        return l10n.gpsStoreCompassNW;
      default:
        return l10n.gpsStoreCompassN;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      targetLat,
      targetLon,
    );
    final bearing = Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      targetLat,
      targetLon,
    );
    final direction = _compass(l10n, compassIndex(bearing));

    return Tooltip(
      message: l10n.gpsStoreDistanceFromHere,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: bearing * math.pi / 180,
            child: Icon(Icons.navigation, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            '${formatDistance(meters)} · $direction',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

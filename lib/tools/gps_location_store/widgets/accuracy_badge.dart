import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../location_source.dart';

class AccuracyBadge extends StatelessWidget {
  final LocationSource source;
  final double? accuracy;

  const AccuracyBadge({
    super.key,
    required this.source,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (source == LocationSource.ip) {
      return StatusBadge(
        label: l10n.gpsStoreSourceApproxIp,
        color: AppTheme.statusAmber,
        icon: Icons.wifi_tethering,
      );
    }

    final label = accuracy != null
        ? l10n.gpsStoreAccuracyMeters(accuracy!.round())
        : l10n.gpsStoreSourceGps;
    return StatusBadge(
      label: label,
      color: AppTheme.statusGreen,
      icon: Icons.gps_fixed,
    );
  }
}

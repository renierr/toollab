import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../location_capture_service.dart';
import '../location_format.dart';
import '../location_source.dart';
import 'accuracy_badge.dart';
import 'map_links.dart';

class CurrentLocationCard extends StatelessWidget {
  final LocationFix fix;
  final bool isLocating;
  final VoidCallback onRefresh;
  final VoidCallback onSave;

  const CurrentLocationCard({
    super.key,
    required this.fix,
    required this.isLocating,
    required this.onRefresh,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      color: AppTheme.accentBlue.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.gpsStoreCurrentTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isLocating ? null : onRefresh,
                  tooltip: l10n.gpsStoreLocateButton,
                  icon: isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              formatCoordinates(fix.latitude, fix.longitude),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AccuracyBadge(source: fix.source, accuracy: fix.accuracy),
            ),
            if (fix.source == LocationSource.ip) ...[
              const SizedBox(height: 8),
              Text(
                l10n.gpsStoreIpFallbackNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentAmberLight,
                ),
              ),
            ],
            const SizedBox(height: 16),
            MapLinks(latitude: fix.latitude, longitude: fix.longitude),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.gpsStoreSaveThis),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

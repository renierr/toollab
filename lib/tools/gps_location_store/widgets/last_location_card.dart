import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../location_format.dart';
import '../saved_location.dart';
import 'accuracy_badge.dart';
import 'map_links.dart';

class LastLocationCard extends StatelessWidget {
  final SavedLocation location;

  const LastLocationCard({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      color: AppTheme.accentGreen.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppTheme.accentGreen.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.where_to_vote, color: AppTheme.accentGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.gpsStoreLastSavedTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AccuracyBadge(
                  source: location.source,
                  accuracy: location.accuracy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              formatCoordinates(location.latitude, location.longitude),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatTimestamp(location),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (location.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(location.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            MapLinks(
              latitude: location.latitude,
              longitude: location.longitude,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../location_format.dart';
import '../saved_location.dart';
import 'accuracy_badge.dart';
import 'map_links.dart';

class LocationListItem extends StatelessWidget {
  final SavedLocation location;
  final VoidCallback onEditDescription;
  final VoidCallback onDelete;

  const LocationListItem({
    super.key,
    required this.location,
    required this.onEditDescription,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    formatCoordinates(location.latitude, location.longitude),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEditDescription();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.gpsStoreEditDescription),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.commonDelete),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                AccuracyBadge(
                  source: location.source,
                  accuracy: location.accuracy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatTimestamp(location),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (location.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(location.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
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

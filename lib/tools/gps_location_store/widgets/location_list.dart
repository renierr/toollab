import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../location_capture_service.dart';
import '../saved_location.dart';
import 'location_list_item.dart';

class LocationList extends StatelessWidget {
  final List<SavedLocation> locations;
  final LocationFix? currentPosition;
  final void Function(SavedLocation) onEditDescription;
  final void Function(SavedLocation) onDelete;

  const LocationList({
    super.key,
    required this.locations,
    this.currentPosition,
    required this.onEditDescription,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            l10n.gpsStoreHistoryTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...locations.map(
          (loc) => LocationListItem(
            location: loc,
            currentPosition: currentPosition,
            onEditDescription: () => onEditDescription(loc),
            onDelete: () => onDelete(loc),
          ),
        ),
      ],
    );
  }
}

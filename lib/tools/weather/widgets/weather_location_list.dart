import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_location.dart';
import '../weather_l10n.dart';
import '../weather_state.dart';
import '../weather_units.dart';
import 'weather_icon_view.dart';
import 'weather_location_actions.dart';

class WeatherLocationList extends StatelessWidget {
  const WeatherLocationList({super.key, required this.onSelected});

  /// Called after a tap, e.g. to close the drawer.
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<WeatherState>();
    final selectedId = state.selected?.id;
    final defaultId = state.defaultLocation?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.weatherPlaces,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.weatherAddPlace,
                icon: const Icon(Icons.add_location_alt_outlined),
                onPressed: () => WeatherLocationActions.addPlace(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: state.locations.length,
            onReorderItem: state.reorder,
            itemBuilder: (context, index) {
              final location = state.locations[index];
              return _LocationTile(
                key: ValueKey(location.id),
                index: index,
                count: state.locations.length,
                location: location,
                selected: location.id == selectedId,
                isDefault: location.id == defaultId,
                onTap: () {
                  state.select(location.id!);
                  onSelected();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.index,
    required this.count,
    required this.location,
    required this.selected,
    required this.isDefault,
    required this.onTap,
  });

  final int index;
  final int count;
  final WeatherLocation location;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<WeatherState>();
    final now = DateTime.now();
    final snapshot = state.snapshotFor(location.id);
    final current = snapshot?.current(now);
    final units = WeatherUnits(state.settings);
    // Long press drags anywhere on the tile; the icon drags at once.
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: selected
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: onTap,
            leading: ReorderableDragStartListener(
              index: index,
              child: current == null
                  ? Icon(
                      location.isDeviceLocation
                          ? Icons.my_location
                          : location.isLocalStation
                          ? Icons.sensors
                          : Icons.place_outlined,
                    )
                  : WeatherIconView(
                      condition: current.condition,
                      isDay: snapshot!.isDayAt(now),
                      size: 36,
                    ),
            ),
            title: Row(
              children: [
                if (location.isDeviceLocation) ...[
                  const Icon(Icons.near_me, size: 14),
                  const SizedBox(width: 4),
                ],
                if (location.isLocalStation) ...[
                  const Icon(Icons.sensors, size: 14),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    WeatherL10n.locationName(l10n, location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDefault) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            subtitle: current == null
                ? null
                : Text(
                    current.condition.label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (current != null)
                  Text(
                    units.temperatureText(current.temperature),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                WeatherLocationMenu(
                  location: location,
                  isDefault: isDefault,
                  index: index,
                  count: count,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

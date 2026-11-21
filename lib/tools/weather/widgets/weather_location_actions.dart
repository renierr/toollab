import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/file_name_dialog.dart';

import '../models/weather_location.dart';
import '../weather_device_location.dart';
import '../weather_l10n.dart';
import '../weather_state.dart';
import 'weather_place_search.dart';
import 'weather_station_sheet.dart';

class WeatherLocationActions {
  WeatherLocationActions._();

  static Future<void> addPlace(BuildContext context) =>
      WeatherPlaceSearch.show(context);

  static Future<void> addDeviceLocation(BuildContext context) async {
    final state = context.read<WeatherState>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final added = await state.addDeviceLocation();
    if (added != null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(deviceErrorText(l10n, state.deviceError))),
    );
  }

  static String deviceErrorText(
    AppLocalizations l10n,
    DeviceLocationError? error,
  ) => switch (error) {
    DeviceLocationError.denied => l10n.weatherLocationDenied,
    DeviceLocationError.serviceDisabled => l10n.weatherLocationOff,
    DeviceLocationError.unsupported => l10n.weatherLocationUnsupported,
    _ => l10n.weatherLocationFailed,
  };

  static Future<void> rename(
    BuildContext context,
    WeatherLocation location,
  ) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<WeatherState>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => FileNameDialog(
        title: l10n.weatherRenameTitle,
        initialValue: WeatherL10n.locationName(l10n, location),
      ),
    );
    if (name != null) await state.rename(location.id!, name);
  }

  static Future<void> remove(
    BuildContext context,
    WeatherLocation location,
  ) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<WeatherState>();
    final messenger = ScaffoldMessenger.of(context);
    final removed = await state.removeLocation(location.id!);
    if (removed == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.weatherRemovedSnack(WeatherL10n.locationName(l10n, removed)),
        ),
        action: SnackBarAction(
          label: l10n.weatherUndo,
          onPressed: () => state.restoreLocation(removed),
        ),
      ),
    );
  }
}

class WeatherLocationMenu extends StatelessWidget {
  const WeatherLocationMenu({
    super.key,
    required this.location,
    required this.isDefault,
    required this.index,
    required this.count,
  });

  final WeatherLocation location;
  final bool isDefault;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        final state = context.read<WeatherState>();
        switch (action) {
          case 'default':
            state.setDefault(location.id);
          case 'up':
            state.reorder(index, index - 1);
          case 'down':
            state.reorder(index, index + 1);
          case 'rename':
            WeatherLocationActions.rename(context, location);
          case 'stations':
            WeatherStationSheet.show(context, location);
          case 'delete':
            WeatherLocationActions.remove(context, location);
        }
      },
      itemBuilder: (context) => [
        if (!isDefault)
          PopupMenuItem(
            value: 'default',
            child: ListTile(
              leading: const Icon(Icons.star_outline_rounded),
              title: Text(l10n.weatherSetDefault),
            ),
          ),
        if (index > 0)
          PopupMenuItem(
            value: 'up',
            child: ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: Text(l10n.weatherMoveUp),
            ),
          ),
        if (index < count - 1)
          PopupMenuItem(
            value: 'down',
            child: ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: Text(l10n.weatherMoveDown),
            ),
          ),
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.weatherRename),
          ),
        ),
        PopupMenuItem(
          value: 'stations',
          child: ListTile(
            leading: const Icon(Icons.cell_tower),
            title: Text(l10n.weatherStations),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.weatherDelete),
          ),
        ),
      ],
    );
  }
}

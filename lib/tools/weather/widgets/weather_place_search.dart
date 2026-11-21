import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../api/weather_http.dart';
import '../models/geo_place.dart';
import '../models/weather_station.dart';
import '../weather_device_location.dart';
import '../weather_state.dart';
import 'weather_local_station_dialog.dart';
import 'weather_location_actions.dart';
import 'weather_coordinates_link.dart';

class WeatherPlaceSearch extends StatefulWidget {
  const WeatherPlaceSearch({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const WeatherPlaceSearch(),
  );

  @override
  State<WeatherPlaceSearch> createState() => _WeatherPlaceSearchState();
}

class _WeatherPlaceSearchState extends State<WeatherPlaceSearch>
    with DisposeCleanup {
  final TextEditingController _controller = TextEditingController();
  List<GeoPlace>? _places;
  List<WeatherStation> _stations = const [];
  bool _searching = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    onDispose(_controller.dispose);
  }

  void _onChanged(String text) {
    final catalog = context.read<WeatherState>().catalog;
    setState(() {
      _stations = text.trim().length < 2
          ? const []
          : (catalog?.search(text, limit: 6) ?? const []);
      _places = null;
      _failed = false;
    });
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final state = context.read<WeatherState>();
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final places = await state.searchPlaces(query, language: language);
      if (!mounted) return;
      setState(() => _places = places);
    } on WeatherException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(GeoPlace place) async {
    final state = context.read<WeatherState>();
    Navigator.pop(context);
    await state.addPlace(place);
  }

  Future<void> _useDevice() async {
    final navigator = Navigator.of(context);
    final parent = navigator.context;
    navigator.pop();
    await WeatherLocationActions.addDeviceLocation(parent);
  }

  Future<void> _addLocalStation() async {
    final navigator = Navigator.of(context);
    final parent = navigator.context;
    navigator.pop();
    await WeatherLocalStationDialog.show(parent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final places = _places;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: l10n.weatherSearchHint,
                  helperText: l10n.weatherSearchPrompt,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _search,
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (WeatherDeviceLocation.isSupported)
                    ListTile(
                      leading: const Icon(Icons.my_location),
                      title: Text(l10n.weatherUseMyLocation),
                      onTap: _useDevice,
                    ),
                  ListTile(
                    leading: const Icon(Icons.sensors),
                    title: Text(l10n.weatherLocalStation),
                    subtitle: Text(l10n.weatherLocalStationSubtitle),
                    onTap: _addLocalStation,
                  ),
                  if (_failed)
                    ListTile(
                      leading: Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(l10n.weatherSearchFailed),
                    ),
                  if (places != null) ...[
                    _Header(l10n.weatherSearchPlaces),
                    if (places.isEmpty)
                      ListTile(title: Text(l10n.weatherSearchNoResults)),
                    for (final p in places)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(p.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            WeatherCoordinatesLink(
                              latitude: p.latitude,
                              longitude: p.longitude,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _pick(p),
                      ),
                  ],
                  if (_stations.isNotEmpty) ...[
                    _Header(l10n.weatherSearchStations),
                    for (final s in _stations)
                      ListTile(
                        leading: const Icon(Icons.cell_tower),
                        title: Text(s.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.id} · ${s.elevation} m'),
                            WeatherCoordinatesLink(
                              latitude: s.latitude,
                              longitude: s.longitude,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _pick(
                          GeoPlace(
                            name: s.name,
                            label: s.name,
                            latitude: s.latitude,
                            longitude: s.longitude,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l10n.weatherSearchAttribution,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

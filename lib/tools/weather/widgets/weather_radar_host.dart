import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../weather_l10n.dart';
import '../weather_radar_state.dart';
import '../weather_settings.dart';
import '../weather_state.dart';
import 'weather_radar_map.dart';

/// Keeps the radar loading while visible and in sync with place and settings.
class WeatherRadarHost extends StatefulWidget {
  const WeatherRadarHost({super.key, required this.builder, this.full = true});

  /// False for the preview, which needs only the current frame.
  final bool full;

  final Widget Function(
    BuildContext context,
    WeatherRadarState radar,
    List<RadarPin> pins,
  )
  builder;

  @override
  State<WeatherRadarHost> createState() => _WeatherRadarHostState();
}

class _WeatherRadarHostState extends State<WeatherRadarHost>
    with DisposeCleanup {
  WeatherSettings? _applied;

  @override
  void initState() {
    super.initState();
    final full = widget.full;
    final radar = context.read<WeatherRadarState>()..attach(full: full);
    onDispose(() => radar.detach(full: full));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WeatherState>();
    final radar = context.read<WeatherRadarState>();
    final selected = state.selected;
    final settings = state.settings;
    // Both notify listeners, which is not allowed while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(settings, _applied)) {
        _applied = settings;
        radar.applySettings(settings);
      }
      if (selected != null) {
        radar.focusOn(selected.latitude, selected.longitude);
      }
    });
    final pins = [
      for (final l in state.locations)
        RadarPin(
          lat: l.latitude,
          lon: l.longitude,
          label: WeatherL10n.locationName(l10n, l),
          selected: l.id == selected?.id,
        ),
    ];
    return widget.builder(context, radar, pins);
  }
}

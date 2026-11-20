import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'weather_state.dart';
import 'widgets/weather_empty_state.dart';
import 'widgets/weather_forecast_view.dart';
import 'widgets/weather_location_list.dart';
import 'widgets/weather_location_pager.dart';
import 'widgets/weather_radar_view.dart';
import 'widgets/weather_settings_sheet.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> with DisposeCleanup {
  static const double _sidebarWidth = 300;
  static const double _radarPanelWidth = 460;

  /// Sidebar, a readable forecast column and the radar panel side by side.
  static const double _radarInlineWidth = 1280;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final state = context.read<WeatherState>();
    unawaited(state.ensureLoaded());
    final timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _autoRefresh(),
    );
    onDispose(timer.cancel);
  }

  void _autoRefresh() {
    final state = context.read<WeatherState>();
    final minutes = state.settings.autoRefreshMinutes;
    final id = state.selected?.id;
    if (minutes == 0 || id == null) return;
    final snapshot = state.snapshotFor(id);
    if (snapshot == null ||
        DateTime.now().difference(snapshot.fetchedAt).inMinutes >= minutes) {
      unawaited(state.refresh(id, force: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WeatherState>();
    final selectedId = state.selected?.id;
    final hasPlaces = state.locations.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.canSplit && hasPlaces;
        final canShowPanel = split && constraints.maxWidth >= _radarInlineWidth;
        final radarInline = canShowPanel && state.settings.radarPanel;
        void setPanel(bool open) =>
            state.updateSettings(state.settings.copyWith(radarPanel: open));
        final Widget body;
        if (!state.isLoaded) {
          body = const Center(child: CircularProgressIndicator());
        } else if (!hasPlaces) {
          body = const WeatherEmptyState();
        } else if (split) {
          body = Row(
            children: [
              SizedBox(
                width: _sidebarWidth,
                child: WeatherLocationList(onSelected: () {}),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: WeatherForecastView(
                  key: ValueKey(selectedId),
                  locationId: selectedId!,
                  showRadarPreview: !radarInline,
                  onOpenRadar: canShowPanel ? () => setPanel(true) : null,
                ),
              ),
              if (radarInline) ...[
                const VerticalDivider(width: 1),
                const SizedBox(
                  width: _radarPanelWidth,
                  child: WeatherRadarView(),
                ),
              ],
            ],
          );
        } else {
          body = const WeatherLocationPager();
        }

        return ToolLayout(
          scaffoldKey: _scaffoldKey,
          title: WeatherTool.config.localizedName(l10n),
          drawer: split || !hasPlaces
              ? null
              : Drawer(
                  child: SafeArea(
                    child: WeatherLocationList(
                      onSelected: () => Navigator.pop(context),
                    ),
                  ),
                ),
          actions: [
            if (!split && hasPlaces)
              IconButton(
                tooltip: l10n.weatherPlaces,
                icon: const Icon(Icons.format_list_bulleted),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            if (canShowPanel)
              IconButton(
                tooltip: radarInline
                    ? l10n.weatherRadarClose
                    : l10n.weatherRadarOpen,
                isSelected: radarInline,
                icon: const Icon(Icons.radar),
                onPressed: () => setPanel(!radarInline),
              ),
            if (selectedId != null)
              IconButton(
                tooltip: l10n.weatherRefresh,
                icon: state.isRefreshing(selectedId)
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: () => state.refresh(selectedId, force: true),
              ),
            IconButton(
              tooltip: l10n.weatherSettings,
              icon: const Icon(Icons.tune),
              onPressed: () => WeatherSettingsSheet.show(context),
            ),
          ],
          child: body,
        );
      },
    );
  }
}

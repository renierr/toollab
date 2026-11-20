import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/rain_outlook.dart';
import '../weather_l10n.dart';
import '../weather_radar_page.dart';
import '../weather_radar_state.dart';
import 'weather_radar_host.dart';
import 'weather_radar_map.dart';
import 'weather_section_card.dart';

class WeatherRadarPreviewCard extends StatelessWidget {
  const WeatherRadarPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WeatherRadarPage()));
    return WeatherSectionCard(
      title: l10n.weatherRadarTitle,
      icon: Icons.radar,
      padding: EdgeInsets.zero,
      trailing: IconButton(
        tooltip: l10n.weatherRadarOpen,
        onPressed: open,
        icon: const Icon(Icons.open_in_full, size: 20),
      ),
      child: SizedBox(
        height: 240,
        child: InkWell(
          onTap: open,
          child: WeatherRadarHost(
            builder: (context, radar, pins) => Stack(
              children: [
                Positioned.fill(
                  child: WeatherRadarMap(
                    radar: radar,
                    pins: pins,
                    interactive: false,
                  ),
                ),
                const Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: _PreviewStatus(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewStatus extends StatelessWidget {
  const _PreviewStatus();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final radar = context.watch<WeatherRadarState>();
    final timeline = radar.timeline;
    final time = radar.currentTime;
    if (timeline == null || time == null) return const SizedBox.shrink();
    final outlook = RainOutlook.from(
      radar.rainSeries,
      timeline.times,
      timeline.nowIndex,
    );
    final text = switch (outlook?.kind) {
      RainOutlookKind.rainingNow => l10n.weatherRadarRainNow,
      RainOutlookKind.rainStops => l10n.weatherRadarRainStops(outlook!.minutes),
      RainOutlookKind.rainSoon => l10n.weatherRadarRainIn(outlook!.minutes),
      RainOutlookKind.dry => l10n.weatherRadarNoRain,
      null => l10n.weatherRadarLoading(radar.loadedCount, radar.frameCount),
    };
    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '${format.time(time)} · $text',
            style: theme.textTheme.labelMedium,
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/rain_outlook.dart';
import '../weather_l10n.dart';
import '../weather_radar_state.dart';
import '../weather_state.dart';
import 'weather_radar_slider.dart';

class WeatherRadarTimeline extends StatelessWidget {
  const WeatherRadarTimeline({super.key});

  static const List<double> speeds = [0.5, 1, 2];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final radar = context.watch<WeatherRadarState>();
    final timeline = radar.timeline;
    final current = radar.currentTime;
    if (timeline == null || current == null) {
      return _Shell(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: radar.failed
              ? Text(l10n.weatherRadarUnavailable, textAlign: TextAlign.center)
              : const LinearProgressIndicator(),
        ),
      );
    }

    final isForecast = timeline.isForecast(current);
    final delta = current.difference(timeline.latestObserved).inMinutes;
    final relative = delta == 0
        ? l10n.weatherRadarNowLabel
        : (delta > 0
              ? l10n.weatherRadarInMinutes(delta)
              : l10n.weatherRadarMinutesAgo(-delta));
    final outlook = RainOutlook.from(
      radar.rainSeries,
      timeline.times,
      timeline.nowIndex,
    );
    final loading = radar.loadedCount < radar.frameCount;
    final accent = isForecast
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    void cycleSpeed() {
      final state = context.read<WeatherState>();
      final i = speeds.indexOf(radar.speed);
      state.updateSettings(
        state.settings.copyWith(radarSpeed: speeds[(i + 1) % speeds.length]),
      );
    }

    return _Shell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  format.time(current),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(relative, style: theme.textTheme.bodyMedium),
                    _Badge(
                      label: isForecast
                          ? l10n.weatherRadarForecast
                          : l10n.weatherRadarObserved,
                      color: accent,
                    ),
                  ],
                ),
                if (outlook != null) _OutlookChip(outlook: outlook),
              ],
            ),
            const SizedBox(height: 6),
            WeatherRadarSlider(
              times: timeline.times,
              index: radar.index,
              nowIndex: timeline.nowIndex,
              loaded: radar.isLoaded,
              rain: radar.rainSeries,
              hourLabel: format.time,
              onChanged: radar.seek,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  tooltip: l10n.weatherRadarStepBack,
                  icon: const Icon(Icons.replay_5),
                  onPressed: () => radar.step(-1),
                ),
                IconButton.filled(
                  tooltip: radar.isPlaying
                      ? l10n.weatherRadarPause
                      : l10n.weatherRadarPlay,
                  iconSize: 32,
                  icon: Icon(
                    radar.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: radar.togglePlay,
                ),
                IconButton(
                  tooltip: l10n.weatherRadarStepForward,
                  icon: const Icon(Icons.forward_5),
                  onPressed: () => radar.step(1),
                ),
                const SizedBox(width: 4),
                ActionChip(
                  avatar: const Icon(Icons.my_location, size: 16),
                  label: Text(l10n.weatherRadarNowLabel),
                  onPressed: radar.jumpToNow,
                ),
                Tooltip(
                  message: l10n.weatherRadarSpeed,
                  child: ActionChip(
                    avatar: const Icon(Icons.speed, size: 16),
                    label: Text(
                      '${radar.speed == radar.speed.roundToDouble() ? radar.speed.round() : radar.speed}×',
                    ),
                    onPressed: cycleSpeed,
                  ),
                ),
              ],
            ),
            if (loading)
              Text(
                l10n.weatherRadarLoading(radar.loadedCount, radar.frameCount),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: .94),
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OutlookChip extends StatelessWidget {
  const _OutlookChip({required this.outlook});

  final RainOutlook outlook;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, text) = switch (outlook.kind) {
      RainOutlookKind.rainingNow => (Icons.umbrella, l10n.weatherRadarRainNow),
      RainOutlookKind.rainStops => (
        Icons.wb_cloudy_outlined,
        l10n.weatherRadarRainStops(outlook.minutes),
      ),
      RainOutlookKind.rainSoon => (
        Icons.umbrella_outlined,
        l10n.weatherRadarRainIn(outlook.minutes),
      ),
      RainOutlookKind.dry => (Icons.wb_sunny_outlined, l10n.weatherRadarNoRain),
    };
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.secondaryContainer,
      side: BorderSide.none,
    );
  }
}

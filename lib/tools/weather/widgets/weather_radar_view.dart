import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../weather_radar_state.dart';
import 'weather_radar_host.dart';
import 'weather_radar_layer_button.dart';
import 'weather_radar_legend.dart';
import 'weather_radar_map.dart';
import 'weather_radar_timeline.dart';

/// Interactive radar: map, map buttons, legend and the time slider card.
class WeatherRadarView extends StatelessWidget {
  const WeatherRadarView({super.key, this.showLayerButton = true});

  /// The full-screen page puts the layer button into its app bar instead.
  final bool showLayerButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WeatherRadarHost(
      builder: (context, radar, pins) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.space) {
            radar.togglePlay();
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            radar.step(-1);
          } else if (key == LogicalKeyboardKey.arrowRight) {
            radar.step(1);
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: WeatherRadarMap(radar: radar, pins: pins),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  if (showLayerButton)
                    const _RoundButton(child: WeatherRadarLayerButton()),
                  _RoundButton(
                    child: IconButton(
                      tooltip: l10n.weatherRadarCenter,
                      icon: const Icon(Icons.center_focus_strong_outlined),
                      onPressed: radar.recenter,
                    ),
                  ),
                  _RoundButton(
                    child: IconButton(
                      tooltip: l10n.weatherRadarZoomIn,
                      icon: const Icon(Icons.add),
                      onPressed: () => radar.zoomAt(1.6, _center(radar)),
                    ),
                  ),
                  _RoundButton(
                    child: IconButton(
                      tooltip: l10n.weatherRadarZoomOut,
                      icon: const Icon(Icons.remove),
                      onPressed: () => radar.zoomAt(1 / 1.6, _center(radar)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WeatherRadarLegend(),
                      const SizedBox(height: 8),
                      const WeatherRadarTimeline(),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          l10n.weatherRadarAttribution,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                shadows: const [Shadow(blurRadius: 3)],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Offset _center(WeatherRadarState radar) {
    final size = radar.viewport.value?.size;
    return size == null ? Offset.zero : Offset(size.width / 2, size.height / 2);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
        shape: const CircleBorder(),
        elevation: 3,
        child: child,
      ),
    );
  }
}

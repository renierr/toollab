import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../api/dwd_radar.dart';

class WeatherRadarLegend extends StatefulWidget {
  const WeatherRadarLegend({super.key});

  @override
  State<WeatherRadarLegend> createState() => _WeatherRadarLegendState();
}

class _WeatherRadarLegendState extends State<WeatherRadarLegend> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.bottomLeft,
            child: _open
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'mm/h',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final (color, mm) in RadarPalette.classes.reversed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 14, height: 10, color: color),
                            const SizedBox(width: 6),
                            Text(
                              mm < 1
                                  ? mm.toString()
                                  : mm.toStringAsFixed(mm % 1 == 0 ? 0 : 1),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              for (final (c, _) in RadarPalette.classes) c,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.weatherRadarLegend,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

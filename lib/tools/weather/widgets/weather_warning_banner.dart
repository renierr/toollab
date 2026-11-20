import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_warning.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import 'weather_warning_sheet.dart';

class WeatherWarningBanner extends StatelessWidget {
  const WeatherWarningBanner({super.key, required this.warnings});

  final List<WeatherWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = WeatherTimeFormat(context);
    final top = warnings.first;
    final color = WeatherColors.warning(top.level);
    final onColor = WeatherColors.onWarning(top.level);
    final now = DateTime.now();
    final timing = top.start.isAfter(now)
        ? l10n.weatherWarningFrom(format.dayTime(top.start))
        : (top.end == null
              ? ''
              : l10n.weatherWarningUntil(format.dayTime(top.end!)));

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => WeatherWarningSheet.show(context, warnings),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: onColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top.headline.isEmpty
                          ? WeatherL10n.warningLevel(l10n, top.level)
                          : top.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        if (timing.isNotEmpty) timing,
                        if (warnings.length > 1)
                          l10n.weatherWarningsMore(warnings.length - 1),
                      ].join(' · '),
                      style: TextStyle(
                        color: onColor.withValues(alpha: .85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: onColor),
            ],
          ),
        ),
      ),
    );
  }
}

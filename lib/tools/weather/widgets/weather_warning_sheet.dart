import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_warning.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';

class WeatherWarningSheet extends StatelessWidget {
  const WeatherWarningSheet({super.key, required this.warnings});

  final List<WeatherWarning> warnings;

  static Future<void> show(
    BuildContext context,
    List<WeatherWarning> warnings,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => WeatherWarningSheet(warnings: warnings),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final w in warnings) _WarningCard(warning: w),
          const SizedBox(height: 8),
          Text(
            l10n.weatherWarningSource,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final WeatherWarning warning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final color = WeatherColors.warning(warning.level);
    final end = warning.end;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text(
                      WeatherL10n.warningLevel(l10n, warning.level),
                      style: TextStyle(
                        color: WeatherColors.onWarning(warning.level),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Text(
                  [
                    l10n.weatherWarningFrom(format.dayTime(warning.start)),
                    if (end != null)
                      l10n.weatherWarningUntil(format.dayTime(end)),
                  ].join(' '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(warning.headline, style: theme.textTheme.titleMedium),
            if (warning.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(warning.description),
            ],
            if (warning.instruction.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                l10n.weatherWarningInstruction,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(warning.instruction, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

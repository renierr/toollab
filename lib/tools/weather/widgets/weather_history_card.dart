import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_history_summary.dart';
import '../weather_history_page.dart';
import '../weather_l10n.dart';
import '../weather_state.dart';
import '../weather_units.dart';
import 'weather_icon_view.dart';
import 'weather_section_card.dart';

/// The last 7 recorded days of a place; opens the history page.
class WeatherHistoryCard extends StatefulWidget {
  const WeatherHistoryCard({
    super.key,
    required this.locationId,
    required this.updatedAt,
    required this.units,
  });

  final int locationId;

  /// Reloads when the place was refreshed, since that records new hours.
  final DateTime updatedAt;
  final WeatherUnits units;

  @override
  State<WeatherHistoryCard> createState() => _WeatherHistoryCardState();
}

class _WeatherHistoryCardState extends State<WeatherHistoryCard> {
  static const int _days = 7;

  late Future<HistorySummary> _summary = _load();

  Future<HistorySummary> _load() async {
    final range = HistoryRange.lastDays(_days, DateTime.now());
    final entries = await context.read<WeatherState>().history(
      widget.locationId,
      range.start,
      range.end,
    );
    return HistorySummary.of(entries, range);
  }

  @override
  void didUpdateWidget(WeatherHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationId != widget.locationId ||
        oldWidget.updatedAt != widget.updatedAt) {
      _summary = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    void open() => WeatherHistoryPage.open(context, widget.locationId);
    return WeatherSectionCard(
      title: l10n.weatherHistory,
      icon: Icons.history,
      trailing: IconButton(
        tooltip: l10n.weatherHistoryOpen,
        onPressed: open,
        icon: const Icon(Icons.chevron_right),
      ),
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<HistorySummary>(
          future: _summary,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            if (summary == null) return const SizedBox(height: 96);
            if (summary.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.weatherHistoryStartsNow,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.weatherHistoryLast7,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final day in summary.days)
                      Expanded(
                        child: _DayColumn(day: day, units: widget.units),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.units});

  final HistoryBucket day;
  final WeatherUnits units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final condition = day.condition;
    return Column(
      children: [
        Text(format.weekdayShort(day.start), style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        if (condition != null)
          WeatherIconView(condition: condition, isDay: true, size: 28)
        else
          const SizedBox(height: 28),
        const SizedBox(height: 4),
        Text(
          units.temperatureText(day.maxTemperature),
          style: theme.textTheme.labelLarge,
        ),
        Text(
          units.temperatureText(day.minTemperature),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

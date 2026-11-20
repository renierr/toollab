import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import 'models/weather_history_summary.dart';
import 'weather_l10n.dart';
import 'weather_state.dart';
import 'weather_units.dart';
import 'widgets/weather_history_chart.dart';
import 'widgets/weather_history_compare.dart';
import 'widgets/weather_history_stats.dart';
import 'widgets/weather_section_card.dart';
import 'widgets/weather_trend_card.dart';

/// Pushed with a `MaterialPageRoute`, so a plain `Scaffold` instead of
/// `ToolLayout`, whose back button needs a GoRouter state.
class WeatherHistoryPage extends StatefulWidget {
  const WeatherHistoryPage({super.key, required this.locationId});

  final int locationId;

  static Future<void> open(BuildContext context, int locationId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WeatherHistoryPage(locationId: locationId),
        ),
      );

  @override
  State<WeatherHistoryPage> createState() => _WeatherHistoryPageState();
}

class _WeatherHistoryPageState extends State<WeatherHistoryPage> {
  static const double _swipeVelocity = 300;

  HistoryRange _range = HistoryRange.containing(
    HistoryPeriod.week,
    DateTime.now(),
  );
  late Future<_HistoryData> _data = _load();

  Future<_HistoryData> _load() async {
    final state = context.read<WeatherState>();
    final range = _range;
    final previous = range.previousYear();
    final results = await Future.wait([
      state.history(widget.locationId, range.start, range.end),
      state.history(widget.locationId, previous.start, previous.end),
    ]);
    return _HistoryData(
      HistorySummary.of(results[0], range),
      HistorySummary.of(results[1], previous),
    );
  }

  bool get _hasNext => _range.shift(1).start.isBefore(DateTime.now());

  void _show(HistoryRange range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _data = _load();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _range.start.isAfter(now) ? now : _range.start,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) _show(HistoryRange.containing(_range.period, picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WeatherState>();
    final location = state.locationById(widget.locationId);
    final units = WeatherUnits(state.settings);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          location == null
              ? l10n.weatherHistory
              : '${l10n.weatherHistory} · ${WeatherL10n.locationName(l10n, location)}',
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > _swipeVelocity) _show(_range.shift(-1));
          if (v < -_swipeVelocity && _hasNext) _show(_range.shift(1));
        },
        child: ReadableScrollPadding(
          maxWidth: 1000,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          builder: (context, padding) => ListView(
            padding: padding,
            children: [
              _PeriodPicker(
                period: _range.period,
                onChanged: (p) =>
                    _show(HistoryRange.containing(p, _range.start)),
              ),
              const SizedBox(height: 8),
              _RangeNavigator(
                range: _range,
                hasNext: _hasNext,
                onPrevious: () => _show(_range.shift(-1)),
                onNext: () => _show(_range.shift(1)),
                onPick: _pickDate,
              ),
              const SizedBox(height: 12),
              FutureBuilder<_HistoryData>(
                future: _data,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _HistoryBody(data: data, units: units);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryData {
  const _HistoryData(this.current, this.previous);

  final HistorySummary current;
  final HistorySummary previous;
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.period, required this.onChanged});

  final HistoryPeriod period;
  final ValueChanged<HistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<HistoryPeriod>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: HistoryPeriod.day,
          label: Text(l10n.weatherHistoryDay),
        ),
        ButtonSegment(
          value: HistoryPeriod.week,
          label: Text(l10n.weatherHistoryWeek),
        ),
        ButtonSegment(
          value: HistoryPeriod.month,
          label: Text(l10n.weatherHistoryMonth),
        ),
        ButtonSegment(
          value: HistoryPeriod.year,
          label: Text(l10n.weatherHistoryYear),
        ),
      ],
      selected: {period},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _RangeNavigator extends StatelessWidget {
  const _RangeNavigator({
    required this.range,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final HistoryRange range;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final last = DateTime(range.end.year, range.end.month, range.end.day - 1);
    final label = switch (range.period) {
      HistoryPeriod.day => DateFormat.yMMMEd(locale).format(range.start),
      HistoryPeriod.week =>
        '${DateFormat.MMMd(locale).format(range.start)} – '
            '${DateFormat.yMMMd(locale).format(last)}',
      HistoryPeriod.month => DateFormat.yMMMM(locale).format(range.start),
      HistoryPeriod.year => '${range.start.year}',
    };
    return Row(
      children: [
        IconButton(
          tooltip: l10n.weatherHistoryPrevious,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
          tooltip: l10n.weatherHistoryNext,
          onPressed: hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.data, required this.units});

  final _HistoryData data;
  final WeatherUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final summary = data.current;
    if (summary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(l10n.weatherHistoryEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              l10n.weatherHistoryStartsNow,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final measured = summary.entries.isEmpty
        ? 0
        : summary.total.measuredHours * 100 ~/ summary.entries.length;
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.weatherHistoryCoverage(
            (summary.coverage(now) * 100).round(),
            measured,
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (summary.range.period == HistoryPeriod.day)
          WeatherTrendCard(
            hours: [for (final e in summary.entries) e.toHourly()],
            units: units,
            title: l10n.weatherDayDetails,
            icon: Icons.schedule,
            singleDay: true,
          )
        else
          WeatherSectionCard(
            title: l10n.weatherHistoryTemperatureChart,
            icon: Icons.bar_chart,
            child: WeatherHistoryChart(summary: summary, units: units),
          ),
        gap,
        WeatherHistoryStats(summary: summary, units: units),
        if (WeatherHistoryCompare.isMeaningful(
          summary,
          data.previous,
          now,
        )) ...[
          gap,
          WeatherHistoryCompare(
            current: summary,
            previous: data.previous,
            units: units,
          ),
        ],
      ],
    );
  }
}

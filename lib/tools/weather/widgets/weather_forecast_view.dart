import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import '../models/daily_forecast.dart';
import '../weather_l10n.dart';
import '../weather_state.dart';
import '../weather_units.dart';
import 'weather_daily_list.dart';
import 'weather_day_sheet.dart';
import 'weather_details_grid.dart';
import 'weather_hero.dart';
import 'weather_history_card.dart';
import 'weather_hourly_strip.dart';
import 'weather_radar_preview_card.dart';
import 'weather_section_card.dart';
import 'weather_source_footer.dart';
import 'weather_trend_card.dart';
import 'weather_warning_banner.dart';

class WeatherForecastView extends StatelessWidget {
  const WeatherForecastView({
    super.key,
    required this.locationId,
    this.showRadarPreview = true,
    this.onOpenRadar,
  });

  static const double _maxContentWidth = 1200;

  final int locationId;

  /// Off when the page already shows the radar beside the forecast.
  final bool showRadarPreview;
  final VoidCallback? onOpenRadar;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WeatherState>();
    final location = state.locationById(locationId);
    final snapshot = state.snapshotFor(locationId);
    if (location == null) return const SizedBox.shrink();
    if (snapshot == null || !snapshot.hasData) {
      return _LoadingOrError(
        loading: state.isRefreshing(locationId) || snapshot == null,
        onRetry: () => state.refresh(locationId, force: true),
      );
    }

    final l10n = AppLocalizations.of(context);
    final units = WeatherUnits(state.settings);
    final now = DateTime.now();
    final current = snapshot.current(now)!;
    final days = snapshot.forecast?.days ?? const <DailyForecast>[];
    final today = days
        .where((d) => WeatherDailyList.isSameDay(d.date, now))
        .firstOrNull;
    final upcoming = snapshot.forecast?.upcoming(now) ?? const [];
    final warnings = [
      for (final w in snapshot.warnings(now))
        if (state.settings.showsWarning(w.level)) w,
    ];

    void openDay(DailyForecast day) => WeatherDaySheet.show(
      context,
      day: day,
      snapshot: snapshot,
      units: units,
    );

    final hero = WeatherHero(
      name: WeatherL10n.locationName(l10n, location),
      latitude: location.latitude,
      longitude: location.longitude,
      current: current,
      today: today,
      isDay: snapshot.isDayAt(now),
      units: units,
      animate: state.settings.animatedIcons,
      observationStation: snapshot.observationStation?.station.name,
    );
    final hourly = upcoming.isEmpty
        ? null
        : WeatherSectionCard(
            title: l10n.weatherHourly,
            icon: Icons.schedule,
            padding: const EdgeInsets.only(bottom: 8),
            child: WeatherHourlyStrip(
              hours: upcoming,
              isDayAt: snapshot.isDayAt,
              units: units,
            ),
          );
    final daily = days.isEmpty
        ? null
        : WeatherSectionCard(
            title: l10n.weatherDaily,
            icon: Icons.calendar_month_outlined,
            child: WeatherDailyList(
              days: days,
              units: units,
              currentTemperature: current.temperature,
              onDayTap: openDay,
            ),
          );
    final details = WeatherDetailsGrid(
      snapshot: snapshot,
      current: current,
      today: today,
      units: units,
      now: now,
    );
    final trend = snapshot.forecast == null
        ? null
        : WeatherTrendCard(hours: snapshot.forecast!.hours, units: units);
    final history = WeatherHistoryCard(
      locationId: locationId,
      updatedAt: snapshot.fetchedAt,
      units: units,
    );
    final footer = WeatherSourceFooter(snapshot: snapshot);

    return RefreshIndicator(
      onRefresh: () => state.refresh(locationId, force: true),
      child: ReadableScrollPadding(
        maxWidth: _maxContentWidth,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        builder: (context, padding) => LayoutBuilder(
          builder: (context, constraints) {
            const gap = SizedBox(height: 16);
            final twoColumns = !constraints.isCompact;
            final children = <Widget>[
              hero,
              if (warnings.isNotEmpty) ...[
                gap,
                WeatherWarningBanner(warnings: warnings),
              ],
              if (hourly != null) ...[gap, hourly],
              if (showRadarPreview) ...[
                gap,
                WeatherRadarPreviewCard(onOpen: onOpenRadar),
              ],
              gap,
              if (twoColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (daily != null) Expanded(flex: 5, child: daily),
                    if (daily != null) const SizedBox(width: 16),
                    Expanded(flex: 4, child: details),
                  ],
                )
              else ...[
                ?daily,
                if (daily != null) gap,
                details,
              ],
              if (trend != null) ...[gap, trend],
              gap,
              history,
              gap,
              footer,
            ];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: children,
            );
          },
        ),
      ),
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(l10n.weatherLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.weatherRetry),
            ),
          ],
        ),
      ),
    );
  }
}

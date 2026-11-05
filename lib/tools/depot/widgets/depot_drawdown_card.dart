import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_drawdowns.dart';
import '../depot_format.dart';
import 'depot_info_row.dart';
import 'depot_mode_chips.dart';

/// Falls below the all-time high and the rises between them.
class DepotDrawdownCard extends StatelessWidget {
  final DepotDrawdowns drawdowns;
  final DepotFormat format;
  final bool showRises;
  final ValueChanged<bool> onModeChanged;

  const DepotDrawdownCard({
    super.key,
    required this.drawdowns,
    required this.format,
    required this.showRises,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = _Dates(Localizations.localeOf(context).toString());
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final current = drawdowns.current;
    final now = DateTime.now();

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-drawdowns'),
        title: Text(
          l10n.depotHighsLowsTitle,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current == null
                  ? l10n.depotDrawdownAtHigh
                  : l10n.depotDrawdownBelowHigh(
                      format.percent(-drawdowns.currentDepth, signed: false),
                      dates.day.format(current.peak),
                      _duration(l10n, now.difference(current.peak)),
                    ),
              style: hint,
            ),
            if (_headline(l10n, dates) case final headline?)
              Text(headline, style: hint),
          ],
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DepotModeChips(
              selected: showRises,
              options: [
                (false, l10n.depotDrawdownModeDrops),
                (true, l10n.depotDrawdownModeRises),
              ],
              onSelected: onModeChanged,
            ),
          ),
          const SizedBox(height: 8),
          if (showRises)
            _RiseList(drawdowns: drawdowns, format: format, dates: dates)
          else
            _DropList(
              drawdowns: drawdowns,
              format: format,
              dates: dates,
              now: now,
            ),
        ],
      ),
    );
  }

  String? _headline(AppLocalizations l10n, _Dates dates) {
    if (showRises) {
      final strongest = drawdowns.strongest;
      if (strongest == null) return null;
      return l10n.depotRiseStrongest(
        format.percent(strongest.percent),
        dates.month.format(strongest.start),
        _duration(l10n, strongest.duration),
      );
    }
    final deepest = drawdowns.deepest;
    if (deepest == null) return null;
    final recovery = deepest.recovery;
    return recovery == null
        ? l10n.depotDrawdownDeepestOpen(
            format.percent(deepest.depth),
            dates.day.format(deepest.peak),
          )
        : l10n.depotDrawdownDeepest(
            format.percent(deepest.depth),
            '${deepest.peak.year}',
            _duration(l10n, recovery),
          );
  }
}

String _duration(AppLocalizations l10n, Duration duration) {
  final days = duration.inDays;
  if (days < 60) return l10n.depotDrawdownDays(days);
  return l10n.depotDrawdownMonths((days / 30.44).round());
}

class _Dates {
  final DateFormat day;
  final DateFormat month;

  _Dates(String locale)
    : day = DateFormat.yMMMd(locale),
      month = DateFormat.yMMM(locale);
}

class _DropList extends StatelessWidget {
  final DepotDrawdowns drawdowns;
  final DepotFormat format;
  final _Dates dates;
  final DateTime now;

  const _DropList({
    required this.drawdowns,
    required this.format,
    required this.dates,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final threshold = format.percent(DepotDrawdowns.minDepth, signed: false);
    final deepest = drawdowns.deepest;
    final average = drawdowns.averageRecovery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DepotInfoRow(
          title: Text(l10n.depotDrawdownCurrent),
          trailing: Text(
            format.percent(drawdowns.currentDepth),
            textAlign: TextAlign.end,
          ),
        ),
        DepotInfoRow(
          padding: const EdgeInsets.only(top: 4),
          title: Text(l10n.depotDrawdownCount(threshold)),
          trailing: Text('${drawdowns.drops.length}', textAlign: TextAlign.end),
        ),
        if (average != null)
          DepotInfoRow(
            padding: const EdgeInsets.only(top: 4),
            title: Text(l10n.depotDrawdownAverageRecovery),
            trailing: Text(_duration(l10n, average), textAlign: TextAlign.end),
          ),
        if (deepest != null) const SizedBox(height: 12),
        for (final drop in drawdowns.drops)
          _Row(
            start: dates.month.format(drop.peak),
            fraction: drop.depth / deepest!.depth,
            color: AppTheme.statusRed,
            details: [
              l10n.depotDrawdownLow(dates.day.format(drop.low)),
              switch (drop.recovered) {
                final recovered? => l10n.depotDrawdownBack(
                  dates.day.format(recovered),
                ),
                null => l10n.depotDrawdownStillBelow,
              },
            ].join(' · '),
            value: format.percent(drop.depth),
            duration: _duration(
              l10n,
              drop.recovery ?? now.difference(drop.peak),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(l10n.depotDrawdownHint(threshold), style: hint),
        ),
      ],
    );
  }
}

class _RiseList extends StatelessWidget {
  final DepotDrawdowns drawdowns;
  final DepotFormat format;
  final _Dates dates;

  const _RiseList({
    required this.drawdowns,
    required this.format,
    required this.dates,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final threshold = format.percent(DepotDrawdowns.minDepth, signed: false);
    final strongest = drawdowns.strongest;
    final current = drawdowns.currentRise;
    final average = drawdowns.averageRise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null)
          DepotInfoRow(
            title: Text(l10n.depotRiseCurrent),
            trailing: Text(
              l10n.depotRiseCurrentValue(
                format.percent(current.percent),
                dates.day.format(current.start),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        DepotInfoRow(
          padding: const EdgeInsets.only(top: 4),
          title: Text(l10n.depotRiseCount(threshold)),
          trailing: Text(
            '${drawdowns.rises.where((r) => r.percent >= DepotDrawdowns.minDepth).length}',
            textAlign: TextAlign.end,
          ),
        ),
        if (average != null)
          DepotInfoRow(
            padding: const EdgeInsets.only(top: 4),
            title: Text(l10n.depotRiseAverage),
            trailing: Text(_duration(l10n, average), textAlign: TextAlign.end),
          ),
        if (strongest != null) const SizedBox(height: 12),
        for (final rise in drawdowns.rises)
          _Row(
            start: dates.month.format(rise.start),
            fraction: rise.percent / strongest!.percent,
            color: AppTheme.statusGreen,
            details: [
              rise.ongoing
                  ? l10n.depotRiseOngoing
                  : l10n.depotRiseUntil(dates.day.format(rise.end)),
              format.money(rise.gain, signed: true),
            ].join(' · '),
            value: format.percent(rise.percent),
            duration: _duration(l10n, rise.duration),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(l10n.depotRiseHint(threshold), style: hint),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String start;
  final double fraction;
  final Color color;
  final String details;
  final String value;
  final String duration;

  const _Row({
    required this.start,
    required this.fraction,
    required this.color,
    required this.details,
    required this.value,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      leading: SizedBox(
        width: 72,
        child: Text(start, style: theme.textTheme.bodySmall),
      ),
      title: SizedBox(
        height: 8,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.02, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(details, style: hint),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
          Text(duration, style: hint),
        ],
      ),
    );
  }
}

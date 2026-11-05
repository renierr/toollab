import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_drawdowns.dart';
import '../depot_format.dart';
import 'depot_info_row.dart';

class DepotDrawdownCard extends StatelessWidget {
  final DepotDrawdowns drawdowns;
  final DepotFormat format;

  const DepotDrawdownCard({
    super.key,
    required this.drawdowns,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final day = DateFormat.yMMMd(locale);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final current = drawdowns.current;
    final deepest = drawdowns.deepest;
    final deepestRecovery = deepest?.recovery;
    final average = drawdowns.averageRecovery;
    final now = DateTime.now();
    final threshold = format.percent(DepotDrawdowns.minDepth, signed: false);

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-drawdowns'),
        title: Text(l10n.depotDrawdownTitle, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current == null
                  ? l10n.depotDrawdownAtHigh
                  : l10n.depotDrawdownBelowHigh(
                      format.percent(-drawdowns.currentDepth, signed: false),
                      day.format(current.peak),
                      _duration(l10n, now.difference(current.peak)),
                    ),
              style: hint,
            ),
            if (deepest != null)
              Text(
                deepestRecovery != null
                    ? l10n.depotDrawdownDeepest(
                        format.percent(deepest.depth),
                        '${deepest.peak.year}',
                        _duration(l10n, deepestRecovery),
                      )
                    : l10n.depotDrawdownDeepestOpen(
                        format.percent(deepest.depth),
                        day.format(deepest.peak),
                      ),
                style: hint,
              ),
          ],
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            trailing: Text(
              '${drawdowns.drops.length}',
              textAlign: TextAlign.end,
            ),
          ),
          if (average != null)
            DepotInfoRow(
              padding: const EdgeInsets.only(top: 4),
              title: Text(l10n.depotDrawdownAverageRecovery),
              trailing: Text(
                _duration(l10n, average),
                textAlign: TextAlign.end,
              ),
            ),
          if (deepest != null) const SizedBox(height: 12),
          for (final drop in drawdowns.drops)
            _DropRow(
              drop: drop,
              fraction: drop.depth / deepest!.depth,
              format: format,
              day: day,
              month: DateFormat.yMMM(locale),
              now: now,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.depotDrawdownHint(threshold), style: hint),
          ),
        ],
      ),
    );
  }
}

String _duration(AppLocalizations l10n, Duration duration) {
  final days = duration.inDays;
  if (days < 60) return l10n.depotDrawdownDays(days);
  return l10n.depotDrawdownMonths((days / 30.44).round());
}

class _DropRow extends StatelessWidget {
  final DepotDrawdown drop;
  final double fraction;
  final DepotFormat format;
  final DateFormat day;
  final DateFormat month;
  final DateTime now;

  const _DropRow({
    required this.drop,
    required this.fraction,
    required this.format,
    required this.day,
    required this.month,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final recovered = drop.recovered;
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      leading: SizedBox(
        width: 72,
        child: Text(month.format(drop.peak), style: theme.textTheme.bodySmall),
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
                color: AppTheme.statusRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          [
            l10n.depotDrawdownLow(day.format(drop.low)),
            recovered == null
                ? l10n.depotDrawdownStillBelow
                : l10n.depotDrawdownBack(day.format(recovered)),
          ].join(' · '),
          style: hint,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            format.percent(drop.depth),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.statusRed,
            ),
          ),
          Text(
            _duration(l10n, drop.recovery ?? now.difference(drop.peak)),
            style: hint,
          ),
        ],
      ),
    );
  }
}

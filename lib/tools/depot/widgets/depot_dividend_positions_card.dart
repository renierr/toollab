import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_holding_avatar.dart';

/// Dividend payers with rhythm, next payment, yield and expected income.
class DepotDividendPositionsCard extends StatelessWidget {
  final List<DepotDividendPosition> positions;
  final DepotFormat format;

  const DepotDividendPositionsCard({
    super.key,
    required this.positions,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (positions.isEmpty) return const SizedBox.shrink();
    final maxAmount = positions.fold<double>(0, (m, p) {
      final amount = _amountOf(p);
      return amount > m ? amount : m;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.depotDividendPositionsTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 4),
            for (final p in positions)
              _PositionRow(
                position: p,
                format: format,
                share: maxAmount <= 0 ? 0 : _amountOf(p) / maxAmount,
              ),
          ],
        ),
      ),
    );
  }

  static double _amountOf(DepotDividendPosition p) =>
      p.expectedNet12m > 0 ? p.expectedNet12m : p.receivedNet12m;
}

class _PositionRow extends StatelessWidget {
  final DepotDividendPosition position;
  final DepotFormat format;
  final double share;

  const _PositionRow({
    required this.position,
    required this.format,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final p = position;
    final h = p.holding;
    final frequency = p.frequency;
    final next = p.next;
    final last = p.lastEvent;
    final yieldPercent = p.yieldPercent;
    final expected = p.expectedNet12m > 0;
    final color = expected
        ? DepotColors.dividendExpected
        : DepotColors.dividendBooked;

    final details = [
      if (frequency != null) DepotPortfolioLabels.frequency(l10n, frequency),
      if (next != null)
        l10n.depotDividendNext(DateFormat.yMMMd(locale).format(next.date)),
      if (last != null)
        l10n.depotDividendLastPerShare(
          NumberFormat.simpleCurrency(
            locale: locale,
            name: p.currency,
          ).format(last.amount),
        ),
      if (yieldPercent != null)
        l10n.depotDividendYieldShort(
          format.percent(yieldPercent, signed: false),
        ),
      if (p.yieldOnCost != null)
        l10n.depotYieldOnCost(format.percent(p.yieldOnCost!, signed: false)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          DepotHoldingAvatar(name: h.name, colorSeed: h.identifier ?? h.id),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        h.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      expected
                          ? l10n.depotDividendPerYear(
                              '≈ ${format.money(p.expectedNet12m)}',
                            )
                          : l10n.depotDividendReceivedShort(
                              format.money(p.receivedNet12m),
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    color: color,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

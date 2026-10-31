import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../models/depot_dividend_history.dart';
import '../models/depot_holding.dart';
import 'depot_info_row.dart';

class DepotDividendHistoryView extends StatelessWidget {
  final DepotDividendHistory history;
  final DepotHolding? holding;

  const DepotDividendHistoryView({
    super.key,
    required this.history,
    this.holding,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h = holding;
    final unknown = h == null
        ? history.unknownCurrency
        : history.unknownByPosition[(h.portfolioId, h.id)] ?? 0;
    final values = <(int, String), double>{};
    if (h == null) {
      values.addAll(history.totals);
    } else {
      for (final entry in history.positions.entries) {
        final (year, currency, portfolio, holdingId) = entry.key;
        if (portfolio == h.portfolioId && holdingId == h.id) {
          values[(year, currency)] = entry.value;
        }
      }
    }
    final keys = values.keys.toList()
      ..sort((a, b) {
        final result = b.$1.compareTo(a.$1);
        return result == 0 ? a.$2.compareTo(b.$2) : result;
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.depotDividendHistoryNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (unknown > 0) Text(l10n.depotYearUnknownCurrency(unknown)),
        if (keys.isEmpty) Text(l10n.depotNoDataYet),
        for (final key in keys)
          _HistoryRow(
            year: key.$1,
            currency: key.$2,
            amount: values[key]!,
            previous: values[(key.$1 - 1, key.$2)],
            total: h == null ? null : history.totals[key],
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final int year;
  final String currency;
  final double amount;
  final double? previous;
  final double? total;
  const _HistoryRow({
    required this.year,
    required this.currency,
    required this.amount,
    required this.previous,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = DepotFormat.of(context, currency);
    final previous = this.previous;
    final total = this.total;
    return DepotInfoRow(
      title: Text('$year · $currency'),
      subtitle: Text(
        [
          if (previous != null && previous != 0)
            l10n.depotDividendHistoryChange(
              format.percent((amount - previous) / previous.abs() * 100),
            ),
          if (total != null && total > 0)
            l10n.depotDividendHistoryShare(
              format.percent(amount / total * 100, signed: false),
            ),
        ].join(' · '),
      ),
      trailing: Text(format.money(amount)),
    );
  }
}

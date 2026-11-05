import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../depot_savings_plans.dart';
import '../depot_state.dart';
import '../models/depot_filters.dart';
import '../models/depot_holding.dart';
import '../models/depot_transaction.dart';
import 'depot_holding_avatar.dart';
import 'depot_info_row.dart';

class DepotSavingsPlanCard extends StatelessWidget {
  final DepotSavingsPlans plans;
  final List<DepotHolding> holdings;

  const DepotSavingsPlanCard({
    super.key,
    required this.plans,
    required this.holdings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = _Money(Localizations.localeOf(context).toString());
    final dayFormat = DateFormat.MMMd(money.locale);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final overdue = plans.overdue;
    final next = plans.next;
    final byKey = {for (final h in holdings) h.key: h};
    final monthly = plans.monthly;

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-savings-plans'),
        title: Text(l10n.depotPlansTitle, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.depotPlansSummary(plans.plans.length, money.of(monthly)),
              style: hint,
            ),
            if (overdue.isNotEmpty)
              _Warning(
                text: l10n.depotPlansOverdue(
                  overdue.map((p) => _nameOf(p, byKey)).join(', '),
                ),
                style: theme.textTheme.bodySmall,
              )
            else if (next.isNotEmpty)
              Text(
                l10n.depotPlansNext(
                  dayFormat.format(next.first.expected),
                  next.length,
                  money.of(DepotSavingsPlans.sum(next)),
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
            title: Text(l10n.depotPlansInvested),
            trailing: Text(money.of(plans.invested), textAlign: TextAlign.end),
          ),
          DepotInfoRow(
            padding: const EdgeInsets.only(top: 4),
            title: Text(l10n.depotPlansOneOff),
            trailing: Text(money.of(plans.oneOff), textAlign: TextAlign.end),
          ),
          DepotInfoRow(
            padding: const EdgeInsets.only(top: 4),
            title: Text(l10n.depotPlansPerYear),
            trailing: Text(
              money.of(monthly.map((k, v) => MapEntry(k, v * 12))),
              textAlign: TextAlign.end,
            ),
          ),
          for (final batch in plans.batches) ...[
            DepotInfoRow(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              title: Text(
                l10n.depotPlansAroundDay(batch.first.day),
                style: theme.textTheme.titleSmall,
              ),
              trailing: Text(
                money.of(DepotSavingsPlans.sum(batch)),
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final plan in batch)
              _PlanRow(
                plan: plan,
                holding: byKey[plan.key],
                money: money,
                dayFormat: dayFormat,
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.depotPlansHint, style: hint),
          ),
        ],
      ),
    );
  }

  static String _nameOf(DepotSavingsPlan plan, Map<String, DepotHolding> by) =>
      by[plan.key]?.name ?? plan.holdingName;
}

/// Money per currency, joined; plans are not converted.
class _Money {
  final String locale;
  final Map<String, DepotFormat> _formats = {};

  _Money(this.locale);

  String of(Map<String, double> amounts) => [
    for (final MapEntry(:key, :value) in amounts.entries)
      if (value.abs() >= 0.005)
        (_formats[key] ??= DepotFormat(locale, key)).money(value),
  ].join(' · ');

  String single(String currency, double value) => of({currency: value});
}

class _PlanRow extends StatelessWidget {
  final DepotSavingsPlan plan;
  final DepotHolding? holding;
  final _Money money;
  final DateFormat dayFormat;

  const _PlanRow({
    required this.plan,
    required this.holding,
    required this.money,
    required this.dayFormat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final monthYear = DateFormat.yMMM(money.locale);
    final name = holding?.name ?? plan.holdingName;
    final first = plan.firstPlanStart;
    final details = [
      l10n.depotPlansRun(
        money.single(plan.currency, plan.rate),
        monthYear.format(plan.since),
        plan.runs,
      ),
      if (first != null) l10n.depotPlansFirstPlan(monthYear.format(first)),
    ].join(' · ');
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      leading: DepotHoldingAvatar(
        name: name,
        colorSeed: holding?.identifier ?? plan.holdingId,
        size: 28,
      ),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        details,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: plan.overdue
          ? _Warning(
              text: l10n.depotPlansMissedMonth(
                DateFormat.MMMM(money.locale).format(plan.expected),
              ),
              style: theme.textTheme.bodySmall,
            )
          : Text(dayFormat.format(plan.expected), textAlign: TextAlign.end),
      onTap: () {
        context.read<DepotPortfolioState>().setActivityFilter(
          DepotActivityFilter(
            portfolioId: plan.portfolioId,
            holdingId: plan.holdingId,
            holdingName: name,
            types: const {DepotTransactionType.buy},
          ),
        );
        context.read<DepotState>().setTab(DepotTab.activities);
      },
    );
  }
}

class _Warning extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _Warning({required this.text, this.style});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: AppTheme.statusAmber,
      ),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: style)),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_format.dart';
import '../depot_activity_groups.dart';
import '../depot_portfolio_state.dart';
import 'depot_activity_filter_bar.dart';
import 'depot_connect_card.dart';
import 'depot_sync_header.dart';
import 'depot_transaction_tile.dart';
import 'depot_year_report_card.dart';

class DepotActivitiesView extends StatelessWidget {
  const DepotActivitiesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();

    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.isConnected && !state.hasData) return const DepotConnectCard();

    final transactions = state.visibleTransactions;
    final rows = state.activityRows;
    final report = state.yearReport;
    final locale = Localizations.localeOf(context).toString();
    // Activities keep their own currency; one formatter per currency.
    final formats = <String, DepotFormat>{};

    return RefreshIndicator(
      onRefresh: state.sync,
      child: ReadableWidth(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              sliver: SliverList.list(
                children: [
                  const DepotSyncHeader(),
                  if (report != null) ...[
                    const SizedBox(height: 8),
                    DepotYearReportCard(
                      reports: state.yearReports,
                      report: report,
                    ),
                  ],
                  const SizedBox(height: 8),
                  const DepotActivityFilterBar(),
                ],
              ),
            ),
            if (transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.depotActivitiesEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  return switch (rows[index]) {
                    DepotActivityMonth(
                      :final month,
                      :final count,
                      :final expanded,
                      :final defaultExpanded,
                    ) =>
                      _MonthHeader(
                        month: month,
                        count: count,
                        expanded: expanded,
                        onTap: () => state.toggleActivityMonth(
                          month,
                          defaultExpanded: defaultExpanded,
                        ),
                        locale: locale,
                      ),
                    DepotActivityItem(transaction: final t) =>
                      DepotTransactionTile(
                        transaction: t,
                        format: formats.putIfAbsent(
                          t.currency,
                          () => DepotFormat(locale, t.currency),
                        ),
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final String locale;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _MonthHeader({
    required this.month,
    required this.locale,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: expanded,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMM(locale).format(month),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    AppLocalizations.of(context).depotActivitiesCount(count),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    ),
  );
}

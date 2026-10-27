import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_format.dart';
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
                      format: DepotFormat.of(context, state.currency),
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
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  return DepotTransactionTile(
                    transaction: t,
                    format: formats.putIfAbsent(
                      t.currency,
                      () => DepotFormat(locale, t.currency),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

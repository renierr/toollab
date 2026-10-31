import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_dividend_state.dart';
import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_holding.dart';
import '../models/depot_dividend_history.dart';
import 'depot_connect_card.dart';
import 'depot_dividend_calendar_card.dart';
import 'depot_dividend_kpis.dart';
import 'depot_dividend_missing_card.dart';
import 'depot_dividend_positions_card.dart';
import 'depot_dividend_source_bar.dart';
import 'depot_dividend_year_chart.dart';
import 'depot_income_chart.dart';
import 'depot_sync_header.dart';

class DepotDividendsView extends StatefulWidget {
  const DepotDividendsView({super.key});

  @override
  State<DepotDividendsView> createState() => _DepotDividendsViewState();
}

class _DepotDividendsViewState extends State<DepotDividendsView> {
  /// The holdings last handed to a refresh; a sync swaps the list, and new
  /// holdings then need their dividend data too.
  List<DepotHolding>? _refreshedFor;

  @override
  void initState() {
    super.initState();
    final dividends = context.read<DepotDividendState>();
    dividends.ensureLoaded();
  }

  Future<void> _refresh({bool force = false}) async {
    final portfolio = context.read<DepotPortfolioState>();
    final dividends = context.read<DepotDividendState>();
    await portfolio.ensureLoaded();
    _refreshedFor = portfolio.holdings;
    await dividends.refresh(
      holdings: portfolio.holdings,
      currency: portfolio.currency,
      force: force,
    );
  }

  Future<void> _pullToRefresh() async {
    await context.read<DepotPortfolioState>().sync();
    if (mounted) await _refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final portfolio = context.watch<DepotPortfolioState>();
    final dividends = context.watch<DepotDividendState>();

    if (!portfolio.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!portfolio.isConnected && !portfolio.hasData) {
      return const DepotConnectCard();
    }
    if (!identical(_refreshedFor, portfolio.holdings)) {
      _refreshedFor = portfolio.holdings;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }

    final format = DepotFormat.of(context, portfolio.currency);
    final calendar = dividends.calendarFor(
      portfolio.holdings,
      portfolio.transactions,
      portfolio.currency,
    );
    final history = DepotDividendHistory(portfolio.transactions);

    return RefreshIndicator(
      onRefresh: _pullToRefresh,
      child: ReadableWidth(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            const DepotSyncHeader(),
            DepotDividendSourceBar(onRefresh: () => _refresh(force: true)),
            if (calendar.entries.isEmpty && calendar.positions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  dividends.isFetching
                      ? l10n.depotDividendLoading
                      : l10n.depotDividendNone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              const SizedBox(height: 4),
              DepotDividendKpis(calendar: calendar, format: format),
              const SizedBox(height: 12),
              DepotDividendMissingCard(
                entries: calendar.missing,
                format: format,
              ),
              DepotDividendCalendarCard(calendar: calendar, format: format),
              DepotDividendYearChart(
                calendar: calendar,
                format: format,
                history: history,
              ),
              DepotIncomeChart(
                months: portfolio.incomeByMonth(),
                format: format,
              ),
              DepotDividendPositionsCard(
                positions: calendar.positions,
                format: format,
                history: history,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(
                  l10n.depotDividendDisclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

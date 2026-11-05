import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_dividend_state.dart';
import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_holding.dart';
import '../dividends/depot_dividend_changes.dart';
import '../models/depot_dividend_history.dart';
import 'depot_connect_card.dart';
import 'depot_dividend_calendar_card.dart';
import 'depot_dividend_changes_card.dart';
import 'depot_dividend_kpis.dart';
import 'depot_dividend_missing_card.dart';
import 'depot_dividend_positions_card.dart';
import 'depot_dividend_source_bar.dart';
import 'depot_dividend_year_chart.dart';
import 'depot_income_chart.dart';
import 'depot_section_scroll_view.dart';
import 'depot_sync_header.dart';

enum _Section { missing, calendar, years, changes, income, positions }

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

  /// Only positions whose dividend data is missing or stale.
  Future<void> _refresh() async {
    final portfolio = context.read<DepotPortfolioState>();
    final dividends = context.read<DepotDividendState>();
    await portfolio.ensureLoaded();
    _refreshedFor = portfolio.holdings;
    await dividends.refresh(
      holdings: portfolio.holdings,
      currency: portfolio.currency,
    );
  }

  Future<void> _pullToRefresh() async {
    await context.read<DepotPortfolioState>().sync();
    if (mounted) await _refresh();
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
    final year = DateTime.now().year;
    final changes = DepotDividendChanges.of(
      year: year,
      holdings: portfolio.holdings,
      assets: dividends.assets,
    );

    final empty = calendar.entries.isEmpty && calendar.positions.isEmpty;

    return DepotSectionScrollView<_Section>(
      onRefresh: _pullToRefresh,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      // The cards carry their own margins.
      spacing: 0,
      header: [
        const DepotSyncHeader(),
        const DepotDividendSourceBar(),
        if (empty)
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
        ],
      ],
      sections: empty
          ? const []
          : [
              if (calendar.missing.isNotEmpty)
                DepotSection(
                  id: _Section.missing,
                  label: l10n.depotDividendNavMissing,
                  icon: Icons.report_outlined,
                  child: DepotDividendMissingCard(
                    entries: calendar.missing,
                    format: format,
                  ),
                ),
              DepotSection(
                id: _Section.calendar,
                label: l10n.depotDividendNavCalendar,
                icon: Icons.event_outlined,
                child: DepotDividendCalendarCard(
                  calendar: calendar,
                  format: format,
                ),
              ),
              if (calendar.years.isNotEmpty)
                DepotSection(
                  id: _Section.years,
                  label: l10n.depotDividendNavYears,
                  icon: Icons.bar_chart_outlined,
                  child: DepotDividendYearChart(
                    calendar: calendar,
                    format: format,
                    history: history,
                  ),
                ),
              if (changes.isNotEmpty)
                DepotSection(
                  id: _Section.changes,
                  label: l10n.depotDividendNavChanges,
                  icon: Icons.trending_up,
                  child: DepotDividendChangesCard(
                    year: year,
                    changes: changes,
                    format: format,
                  ),
                ),
              DepotSection(
                id: _Section.income,
                label: l10n.depotDividendNavIncome,
                icon: Icons.savings_outlined,
                child: DepotIncomeChart(
                  months: portfolio.incomeByMonth(),
                  format: format,
                ),
              ),
              if (calendar.positions.isNotEmpty)
                DepotSection(
                  id: _Section.positions,
                  label: l10n.depotDividendNavPositions,
                  icon: Icons.list_alt_outlined,
                  child: DepotDividendPositionsCard(
                    positions: calendar.positions,
                    format: format,
                    history: history,
                  ),
                ),
            ],
    );
  }
}

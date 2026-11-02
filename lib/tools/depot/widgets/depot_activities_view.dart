import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_format.dart';
import '../depot_activity_groups.dart';
import '../depot_portfolio_state.dart';
import 'depot_activity_filter_bar.dart';
import 'depot_connect_card.dart';
import 'depot_section_nav.dart';
import 'depot_sync_header.dart';
import 'depot_transaction_tile.dart';
import 'depot_year_report_card.dart';

class DepotActivitiesView extends StatefulWidget {
  const DepotActivitiesView({super.key});

  @override
  State<DepotActivitiesView> createState() => _DepotActivitiesViewState();
}

class _DepotActivitiesViewState extends State<DepotActivitiesView>
    with DisposeCleanup {
  // How far below the viewport top a month header still counts as current.
  static const double _activeSlack = 24;
  static const int _maxJumpSteps = 30;

  late final ScrollController _controller;
  final Map<DateTime, GlobalKey> _monthKeys = {};
  List<DepotActivityRow>? _rows;
  int _rowCount = 0;

  /// Month headers in list order, with their row index.
  List<({int index, DateTime month})> _months = const [];
  int? _activeYear;
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    onDispose(_controller.dispose);
  }

  GlobalKey _keyOf(DateTime month) =>
      _monthKeys.putIfAbsent(month, GlobalKey.new);

  void _indexMonths(List<DepotActivityRow> rows) {
    if (identical(rows, _rows)) return;
    _rows = rows;
    _rowCount = rows.length;
    _months = [
      for (final (index, row) in rows.indexed)
        if (row is DepotActivityMonth) (index: index, month: row.month),
    ];
  }

  RenderBox? _boxOf(DateTime month) {
    final box = _monthKeys[month]?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box : null;
  }

  /// The list is lazy, so a month far away is not built yet: jump near it by
  /// its position in the list, then step a screen at a time until it is.
  Future<void> _jumpToYear(int year) async {
    final entry = _months.where((m) => m.month.year == year).firstOrNull;
    if (entry == null || !_controller.hasClients) return;
    final (:index, :month) = entry;
    setState(() => _activeYear = year);
    _jumping = true;
    try {
      for (var step = 0; step < _maxJumpSteps; step++) {
        final target = _monthKeys[month]?.currentContext;
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
          return;
        }
        final position = _controller.position;
        final double next;
        if (step == 0) {
          next = position.maxScrollExtent * index / _rowCount;
        } else {
          final built = _months
              .where((m) => _boxOf(m.month) != null)
              .firstOrNull;
          if (built == null) return;
          final direction = built.index < index ? 1 : -1;
          next = position.pixels + direction * position.viewportDimension;
        }
        _controller.jumpTo(
          next.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
    } finally {
      _jumping = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_jumping ||
        notification.depth != 0 ||
        notification is! ScrollUpdateNotification) {
      return false;
    }
    final viewport = notification.context?.findRenderObject();
    if (viewport is! RenderBox) return false;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    int? current;
    int? firstBuilt;
    for (final (position, entry) in _months.indexed) {
      final box = _boxOf(entry.month);
      if (box == null) continue;
      firstBuilt ??= position;
      final top = box.localToGlobal(Offset.zero).dy - viewportTop;
      if (top > _activeSlack) break;
      current = entry.month.year;
    }
    // Inside a long month whose header scrolled away, the month before the
    // first header still built is the one in view.
    if (current == null && firstBuilt != null) {
      current = _months[firstBuilt > 0 ? firstBuilt - 1 : 0].month.year;
    }
    if (current != null && current != _activeYear) {
      setState(() => _activeYear = current);
    }
    return false;
  }

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
    _indexMonths(rows);
    final report = state.yearReport;
    final locale = Localizations.localeOf(context).toString();
    // Activities keep their own currency; one formatter per currency.
    final formats = <String, DepotFormat>{};
    final years = <int>{for (final entry in _months) entry.month.year};
    final links = [
      for (final year in years) DepotSectionLink(id: year, label: '$year'),
    ];

    return ReadableWidth(
      child: Column(
        children: [
          if (links.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: DepotSectionNav<int>(
                links: links,
                active: years.contains(_activeYear) ? _activeYear : years.first,
                onSelect: _jumpToYear,
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                onRefresh: state.sync,
                child: CustomScrollView(
                  controller: _controller,
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
                                key: _keyOf(month),
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
            ),
          ),
        ],
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
    super.key,
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

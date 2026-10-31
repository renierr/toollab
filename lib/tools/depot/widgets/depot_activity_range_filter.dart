import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_state.dart';
import '../models/depot_filters.dart';

class DepotActivityRangeFilter extends StatelessWidget {
  const DepotActivityRangeFilter({super.key});

  Future<void> _select(BuildContext context) async {
    final state = context.read<DepotPortfolioState>();
    final l10n = AppLocalizations.of(context);
    final range = state.activityFilter.dateRange;
    var first = DateTime(1900);
    var last = DateTime(2100, 12, 31);
    for (final date in [
      DateTime.now(),
      for (final t in state.transactions) t.datetime,
      if (range != null) ...[range.start, range.end],
    ]) {
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(first)) first = day;
      if (day.isAfter(last)) last = day;
    }
    final today = DateTime.now();
    final start = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: range?.start ?? today,
      helpText: l10n.depotActivitiesStartDate,
    );
    if (start == null || !context.mounted) return;
    final previousEnd = range?.end;
    final initialEnd = previousEnd != null && !previousEnd.isBefore(start)
        ? previousEnd
        : start;
    final end = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: last,
      initialDate: initialEnd,
      helpText: l10n.depotActivitiesEndDate,
    );
    if (end == null || !context.mounted) return;
    final current = context.read<DepotPortfolioState>();
    current.setActivityFilter(
      current.activityFilter.copyWith(
        dateRange: DepotActivityDateRange(start, end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DepotPortfolioState>();
    final range = state.activityFilter.dateRange;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _select(context),
              icon: const Icon(Icons.date_range_outlined),
              label: Text(l10n.depotActivitiesChooseRange),
            ),
            if (range != null)
              IconButton(
                tooltip: l10n.depotActivitiesClearRange,
                onPressed: () => state.setActivityFilter(
                  state.activityFilter.copyWith(clearDateRange: true),
                ),
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
        if (range != null)
          Text(
            l10n.depotActivitiesRange(
              date.format(range.start),
              date.format(range.end),
            ),
          ),
      ],
    );
  }
}

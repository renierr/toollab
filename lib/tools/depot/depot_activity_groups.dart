import 'models/depot_transaction.dart';

sealed class DepotActivityRow {
  const DepotActivityRow();
}

class DepotActivityMonth extends DepotActivityRow {
  final DateTime month;
  final int count;
  final bool expanded;
  final bool defaultExpanded;
  const DepotActivityMonth(
    this.month, {
    required this.count,
    required this.expanded,
    required this.defaultExpanded,
  });
}

class DepotActivityItem extends DepotActivityRow {
  final DepotTransaction transaction;
  const DepotActivityItem(this.transaction);
}

class DepotActivityGroups {
  DepotActivityGroups(Iterable<DepotTransaction> transactions) {
    for (final transaction in transactions) {
      final date = transaction.datetime;
      final month = DateTime(date.year, date.month);
      (_months[month] ??= []).add(transaction);
    }
    _sorted = _months.keys.toList()..sort((a, b) => b.compareTo(a));
  }

  final Map<DateTime, List<DepotTransaction>> _months = {};
  late final List<DateTime> _sorted;

  List<DepotActivityRow> rows({
    bool Function(DateTime month, bool defaultExpanded)? isExpanded,
  }) {
    final rows = <DepotActivityRow>[];
    for (final (index, month) in _sorted.indexed) {
      final defaultExpanded = index < 2;
      final expanded =
          isExpanded?.call(month, defaultExpanded) ?? defaultExpanded;
      rows.add(
        DepotActivityMonth(
          month,
          count: _months[month]!.length,
          expanded: expanded,
          defaultExpanded: defaultExpanded,
        ),
      );
      if (expanded) {
        rows.addAll(_months[month]!.map(DepotActivityItem.new));
      }
    }
    return rows;
  }
}

List<DepotActivityRow> depotActivityRows(
  Iterable<DepotTransaction> transactions, {
  bool Function(DateTime month, bool defaultExpanded)? isExpanded,
}) => DepotActivityGroups(transactions).rows(isExpanded: isExpanded);

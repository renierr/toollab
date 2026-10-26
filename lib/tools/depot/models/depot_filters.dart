import 'depot_holding.dart';
import 'depot_transaction.dart';

/// Gain and return sort by the selected period's figures.
enum DepotHoldingSort { returnPercent, gain, value, name }

class DepotHoldingFilter {
  final String query;

  /// Empty means every kind.
  final Set<DepotHoldingKind> kinds;
  final bool showSold;
  final DepotHoldingSort sort;

  const DepotHoldingFilter({
    this.query = '',
    this.kinds = const {},
    this.showSold = false,
    this.sort = DepotHoldingSort.returnPercent,
  });

  DepotHoldingFilter copyWith({
    String? query,
    Set<DepotHoldingKind>? kinds,
    bool? showSold,
    DepotHoldingSort? sort,
  }) => DepotHoldingFilter(
    query: query ?? this.query,
    kinds: kinds ?? this.kinds,
    showSold: showSold ?? this.showSold,
    sort: sort ?? this.sort,
  );

  bool matches(DepotHolding h) {
    if (!showSold && h.isSold) return false;
    if (kinds.isNotEmpty && !kinds.contains(h.kind)) return false;
    return _matchesQuery(query, [h.name, h.isin, h.symbol]);
  }

  /// Holdings without figures for the period sort last.
  int compare(
    DepotHolding a,
    DepotHolding b,
    DepotHoldingPerformance? Function(DepotHolding) performanceOf,
  ) => switch (sort) {
    DepotHoldingSort.returnPercent => _descending(
      performanceOf(a)?.returnPercent,
      performanceOf(b)?.returnPercent,
    ),
    DepotHoldingSort.gain => _descending(
      performanceOf(a)?.gain,
      performanceOf(b)?.gain,
    ),
    DepotHoldingSort.value => b.currentValue.compareTo(a.currentValue),
    DepotHoldingSort.name => a.name.toLowerCase().compareTo(
      b.name.toLowerCase(),
    ),
  };

  static int _descending(double? a, double? b) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}

class DepotActivityFilter {
  final String query;

  /// Empty means every type.
  final Set<DepotTransactionType> types;

  const DepotActivityFilter({this.query = '', this.types = const {}});

  DepotActivityFilter copyWith({
    String? query,
    Set<DepotTransactionType>? types,
  }) => DepotActivityFilter(
    query: query ?? this.query,
    types: types ?? this.types,
  );

  bool matches(DepotTransaction t) {
    if (types.isNotEmpty && !types.contains(t.type)) return false;
    return _matchesQuery(query, [t.holdingName, t.broker]);
  }
}

bool _matchesQuery(String query, List<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f != null && f.toLowerCase().contains(q));
}

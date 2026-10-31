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
  final DepotActivityDateRange? dateRange;
  final String? portfolioId;
  final String? holdingId;
  final String? holdingName;

  const DepotActivityFilter({
    this.query = '',
    this.types = const {},
    this.dateRange,
    this.portfolioId,
    this.holdingId,
    this.holdingName,
  });

  DepotActivityFilter copyWith({
    String? query,
    Set<DepotTransactionType>? types,
    DepotActivityDateRange? dateRange,
    bool clearDateRange = false,
    String? portfolioId,
    String? holdingId,
    String? holdingName,
    bool clearHolding = false,
  }) => DepotActivityFilter(
    query: query ?? this.query,
    types: types ?? this.types,
    dateRange: clearDateRange ? null : dateRange ?? this.dateRange,
    portfolioId: clearHolding ? null : portfolioId ?? this.portfolioId,
    holdingId: clearHolding ? null : holdingId ?? this.holdingId,
    holdingName: clearHolding ? null : holdingName ?? this.holdingName,
  );

  bool matches(DepotTransaction t) {
    if (holdingId != null &&
        (t.holdingId != holdingId || t.portfolioId != portfolioId)) {
      return false;
    }
    if (types.isNotEmpty && !types.contains(t.type)) return false;
    if (dateRange != null && !dateRange!.contains(t.datetime)) return false;
    return _matchesQuery(query, [t.holdingName, t.broker]);
  }
}

class DepotActivityDateRange {
  final DateTime start;
  final DateTime end;

  DepotActivityDateRange(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('End date must not precede start date');
    }
  }

  bool contains(DateTime datetime) {
    final day = DateTime(datetime.year, datetime.month, datetime.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

bool _matchesQuery(String query, List<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f != null && f.toLowerCase().contains(q));
}

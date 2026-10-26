import 'depot_holding.dart';
import 'depot_transaction.dart';

enum DepotHoldingSort { value, gain, gainPercent, name }

enum DepotChartRange { month1, month3, ytd, year1, year3, max }

class DepotHoldingFilter {
  final String query;

  /// Empty means every type.
  final Set<DepotAssetType> assetTypes;
  final bool showSold;
  final DepotHoldingSort sort;

  const DepotHoldingFilter({
    this.query = '',
    this.assetTypes = const {},
    this.showSold = false,
    this.sort = DepotHoldingSort.value,
  });

  DepotHoldingFilter copyWith({
    String? query,
    Set<DepotAssetType>? assetTypes,
    bool? showSold,
    DepotHoldingSort? sort,
  }) => DepotHoldingFilter(
    query: query ?? this.query,
    assetTypes: assetTypes ?? this.assetTypes,
    showSold: showSold ?? this.showSold,
    sort: sort ?? this.sort,
  );

  bool matches(DepotHolding h) {
    if (!showSold && h.isSold) return false;
    if (assetTypes.isNotEmpty && !assetTypes.contains(h.assetType)) {
      return false;
    }
    return _matchesQuery(query, [h.name, h.isin, h.symbol]);
  }

  int compare(DepotHolding a, DepotHolding b) => switch (sort) {
    DepotHoldingSort.value => b.currentValue.compareTo(a.currentValue),
    DepotHoldingSort.gain => b.totalGain.compareTo(a.totalGain),
    DepotHoldingSort.gainPercent => b.unrealizedReturn.compareTo(
      a.unrealizedReturn,
    ),
    DepotHoldingSort.name => a.name.toLowerCase().compareTo(
      b.name.toLowerCase(),
    ),
  };
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

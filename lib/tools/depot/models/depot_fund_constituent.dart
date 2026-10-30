/// One of a fund's largest holdings, as a share of the whole fund.
class DepotFundConstituent {
  final String name;
  final String? isin;
  final String? symbol;
  final double weight;

  const DepotFundConstituent({
    required this.name,
    this.isin,
    this.symbol,
    required this.weight,
  });

  /// Merges the same company across funds and direct positions.
  String get key => isin ?? symbol ?? name.toLowerCase();

  factory DepotFundConstituent.fromMap(Map<String, Object?> row) =>
      DepotFundConstituent(
        name: row['name'] as String,
        isin: row['isin'] as String?,
        symbol: row['symbol'] as String?,
        weight: (row['weight'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
    'name': name,
    'isin': isin,
    'symbol': symbol,
    'weight': weight,
  };

  /// Reads the JSON the profile cache used before it had its own tables.
  static DepotFundConstituent? fromLegacyJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final weight = raw['weight'];
    if (name is! String ||
        name.isEmpty ||
        weight is! num ||
        !weight.isFinite ||
        weight <= 0 ||
        weight > 1) {
      return null;
    }
    return DepotFundConstituent(
      name: name,
      isin: raw['isin'] as String?,
      symbol: raw['symbol'] as String?,
      weight: weight.toDouble(),
    );
  }
}

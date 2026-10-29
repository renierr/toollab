/// What Yahoo knows about a security beyond its quote: sector, industry and
/// country for a single stock, or the sector and country mix of a fund.
class DepotAssetProfile {
  final String? sector;
  final String? industry;
  final String? country;

  /// Share per sector for funds, 0..1 and summing to 1.
  final Map<String, double> sectorShares;

  /// Share per country for funds, derived from the top holdings, 0..1.
  final Map<String, double> countryShares;

  final DateTime fetchedAt;

  const DepotAssetProfile({
    this.sector,
    this.industry,
    this.country,
    this.sectorShares = const {},
    this.countryShares = const {},
    required this.fetchedAt,
  });

  bool get isEmpty =>
      sector == null &&
      industry == null &&
      country == null &&
      sectorShares.isEmpty &&
      countryShares.isEmpty;

  DepotAssetProfile copyWith({Map<String, double>? countryShares}) =>
      DepotAssetProfile(
        sector: sector,
        industry: industry,
        country: country,
        sectorShares: sectorShares,
        countryShares: countryShares ?? this.countryShares,
        fetchedAt: fetchedAt,
      );

  factory DepotAssetProfile.fromJson(Map<String, dynamic> json) {
    final fetched = json['fetchedAt'];
    return DepotAssetProfile(
      sector: _text(json['sector']),
      industry: _text(json['industry']),
      country: _text(json['country']),
      sectorShares: _shares(json['sectorShares']),
      countryShares: _shares(json['countryShares']),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        fetched is num
            ? fetched.round()
            : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    if (sector != null) 'sector': sector,
    if (industry != null) 'industry': industry,
    if (country != null) 'country': country,
    if (sectorShares.isNotEmpty) 'sectorShares': sectorShares,
    if (countryShares.isNotEmpty) 'countryShares': countryShares,
    'fetchedAt': fetchedAt.millisecondsSinceEpoch,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, double> _shares(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num && value > 0) {
        result[key] = value.toDouble();
      }
    }
    return result;
  }
}

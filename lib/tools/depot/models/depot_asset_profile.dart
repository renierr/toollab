import 'depot_fund_constituent.dart';
import 'depot_holding.dart';

/// What market data knows about a security beyond its quote: sector, industry
/// and country for a single stock, or the sector, country and holdings mix of
/// a fund.
class DepotAssetProfile {
  /// Bumped when a fetch path improves, so older entries are fetched once more.
  static const int currentVersion = 4;

  final String? sector;
  final String? industry;
  final String? country;
  final String? region;
  final int cacheVersion;

  /// Stock, ETF or fund as the data source reports it; null when unknown.
  final DepotHoldingKind? kind;

  /// Known shares of the whole fund, which may sum to less than 1.
  final Map<String, double> sectorShares;

  /// Known shares of the whole fund, which may sum to less than 1.
  final Map<String, double> countryShares;

  /// A fund's largest holdings, largest first.
  final List<DepotFundConstituent> constituents;

  final DateTime fetchedAt;

  const DepotAssetProfile({
    this.sector,
    this.industry,
    this.country,
    this.region,
    this.cacheVersion = currentVersion,
    this.kind,
    this.sectorShares = const {},
    this.countryShares = const {},
    this.constituents = const [],
    required this.fetchedAt,
  });

  bool get isEmpty =>
      sector == null &&
      industry == null &&
      country == null &&
      region == null &&
      sectorShares.isEmpty &&
      countryShares.isEmpty &&
      constituents.isEmpty;

  DepotAssetProfile copyWith({
    String? country,
    DepotHoldingKind? kind,
    Map<String, double>? sectorShares,
    Map<String, double>? countryShares,
    List<DepotFundConstituent>? constituents,
  }) => DepotAssetProfile(
    sector: sector,
    industry: industry,
    country: country ?? this.country,
    region: region,
    cacheVersion: cacheVersion,
    kind: kind ?? this.kind,
    sectorShares: sectorShares ?? this.sectorShares,
    countryShares: countryShares ?? this.countryShares,
    constituents: constituents ?? this.constituents,
    fetchedAt: fetchedAt,
  );

  factory DepotAssetProfile.fromJson(Map<String, dynamic> json) {
    final fetched = json['fetchedAt'];
    final version = (json['cacheVersion'] as num?)?.toInt() ?? 1;
    final kind = json['kind'];
    return DepotAssetProfile(
      sector: _text(json['sector']),
      industry: _text(json['industry']),
      country: _text(json['country']),
      region: _text(json['region']),
      cacheVersion: version,
      kind: DepotHoldingKind.values.asNameMap()[kind],
      sectorShares: version >= 3 ? _shares(json['sectorShares']) : const {},
      countryShares: version >= 3 ? _shares(json['countryShares']) : const {},
      constituents: [
        for (final raw in json['constituents'] as List? ?? const [])
          ?DepotFundConstituent.fromJson(raw),
      ],
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        fetched is num
            ? fetched.round()
            : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'sector': ?sector,
    'industry': ?industry,
    'country': ?country,
    'region': ?region,
    'cacheVersion': cacheVersion,
    if (kind != null) 'kind': kind!.name,
    if (sectorShares.isNotEmpty) 'sectorShares': sectorShares,
    if (countryShares.isNotEmpty) 'countryShares': countryShares,
    if (constituents.isNotEmpty)
      'constituents': [for (final c in constituents) c.toJson()],
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
      if (key is String &&
          value is num &&
          value.isFinite &&
          value > 0 &&
          value <= 1) {
        result[key] = value.toDouble();
      }
    }
    return result;
  }
}

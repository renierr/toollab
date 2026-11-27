enum DepotEtcSettlement { physical, cash }

/// What onvista knows about an ETC: issuer, underlying, delivery and spread.
class DepotEtcProfile {
  final String? issuer;

  /// In German as onvista names it, e.g. "Goldpreis".
  final String? underlying;
  final DepotEtcSettlement? settlement;
  final bool openEnded;
  final DateTime? maturity;

  /// Ask over bid, in percent.
  final double? spreadPercent;
  final DateTime fetchedAt;

  const DepotEtcProfile({
    this.issuer,
    this.underlying,
    this.settlement,
    this.openEnded = false,
    this.maturity,
    this.spreadPercent,
    required this.fetchedAt,
  });

  factory DepotEtcProfile.fromMap(Map<String, Object?> map) {
    DateTime? date(Object? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
    return DepotEtcProfile(
      issuer: map['issuer'] as String?,
      underlying: map['underlying'] as String?,
      settlement: DepotEtcSettlement.values.asNameMap()[map['settlement']],
      openEnded: map['open_ended'] == 1,
      maturity: date(map['maturity']),
      spreadPercent: map['spread_percent'] as double?,
      fetchedAt: date(map['fetched_at'])!,
    );
  }

  /// The `etc_profiles` columns, without the key.
  Map<String, Object?> toMap() => {
    'issuer': issuer,
    'underlying': underlying,
    'settlement': settlement?.name,
    'open_ended': openEnded ? 1 : 0,
    'maturity': maturity?.millisecondsSinceEpoch,
    'spread_percent': spreadPercent,
    'fetched_at': fetchedAt.millisecondsSinceEpoch,
  };
}

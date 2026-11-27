/// What onvista knows about a bond: terms, issuer and current yield. Prices
/// are percent of the nominal.
class DepotBondProfile {
  final String? issuer;

  /// Issuer's country, in German as onvista names it.
  final String? country;

  /// Currency of the nominal and the coupons.
  final String? currency;

  /// Yearly coupon in percent; 0 for a zero bond.
  final double? coupon;
  final int? couponMonths;
  final DateTime? nextCoupon;

  /// Null for a perpetual bond.
  final DateTime? maturity;
  final bool callable;
  final double? yieldToMaturity;
  final double? currentYield;
  final double? duration;
  final double? pricePercent;
  final double? previousPricePercent;
  final DateTime? priceAt;
  final DateTime fetchedAt;

  const DepotBondProfile({
    this.issuer,
    this.country,
    this.currency,
    this.coupon,
    this.couponMonths,
    this.nextCoupon,
    this.maturity,
    this.callable = false,
    this.yieldToMaturity,
    this.currentYield,
    this.duration,
    this.pricePercent,
    this.previousPricePercent,
    this.priceAt,
    required this.fetchedAt,
  });

  factory DepotBondProfile.fromMap(Map<String, Object?> map) {
    DateTime? date(Object? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
    return DepotBondProfile(
      issuer: map['issuer'] as String?,
      country: map['country'] as String?,
      currency: map['currency'] as String?,
      coupon: map['coupon'] as double?,
      couponMonths: map['coupon_months'] as int?,
      nextCoupon: date(map['next_coupon']),
      maturity: date(map['maturity']),
      callable: map['callable'] == 1,
      yieldToMaturity: map['yield_to_maturity'] as double?,
      currentYield: map['current_yield'] as double?,
      duration: map['duration'] as double?,
      pricePercent: map['price_percent'] as double?,
      previousPricePercent: map['previous_price_percent'] as double?,
      priceAt: date(map['price_at']),
      fetchedAt: date(map['fetched_at'])!,
    );
  }

  /// The `bond_profiles` columns, without the key.
  Map<String, Object?> toMap() => {
    'issuer': issuer,
    'country': country,
    'currency': currency,
    'coupon': coupon,
    'coupon_months': couponMonths,
    'next_coupon': nextCoupon?.millisecondsSinceEpoch,
    'maturity': maturity?.millisecondsSinceEpoch,
    'callable': callable ? 1 : 0,
    'yield_to_maturity': yieldToMaturity,
    'current_yield': currentYield,
    'duration': duration,
    'price_percent': pricePercent,
    'previous_price_percent': previousPricePercent,
    'price_at': priceAt?.millisecondsSinceEpoch,
    'fetched_at': fetchedAt.millisecondsSinceEpoch,
  };
}

enum DepotDividendFrequency {
  monthly(30.4),
  quarterly(91.3),
  semiannual(182.6),
  annual(365.25),
  irregular(365.25);

  final double days;

  const DepotDividendFrequency(this.days);

  /// Guessed from the gaps between the most recent ex-dates.
  static DepotDividendFrequency? of(List<DepotDividendEvent> events) {
    if (events.isEmpty) return null;
    if (events.length == 1) return annual;
    final recent = events.length > 9
        ? events.sublist(events.length - 9)
        : events;
    final gaps = [
      for (var i = 1; i < recent.length; i++)
        recent[i].exDate.difference(recent[i - 1].exDate).inDays,
    ]..sort();
    final median = gaps[gaps.length ~/ 2];
    if (median < 20) return irregular;
    if (median < 50) return monthly;
    if (median < 130) return quarterly;
    if (median < 250) return semiannual;
    if (median < 450) return annual;
    return irregular;
  }
}

/// One distribution as reported by the market data source.
class DepotDividendEvent {
  final DateTime exDate;

  /// Per share, in the listing currency of the asset.
  final double amount;

  const DepotDividendEvent({required this.exDate, required this.amount});

  factory DepotDividendEvent.fromMap(Map<String, Object?> map) =>
      DepotDividendEvent(
        exDate: DateTime.fromMillisecondsSinceEpoch(map['ex_date'] as int),
        amount: map['amount'] as double,
      );

  Map<String, Object?> toMap(String assetKey) => {
    'asset_key': assetKey,
    'ex_date': exDate.millisecondsSinceEpoch,
    'amount': amount,
  };
}

/// Dividend history and the next announced date of one asset, cached from
/// Yahoo Finance. Keyed by ISIN, or by symbol when the holding has none.
class DepotDividendAsset {
  final String key;

  /// Null when no listing was found; cached anyway so it is not looked up
  /// again on every opening.
  final String? symbol;
  final String currency;

  /// Converts [currency] into [fxCurrency], the portfolio currency.
  final String fxCurrency;
  final double fxRate;
  final DateTime? nextExDate;
  final DateTime? nextPayDate;
  final DateTime fetchedAt;

  /// Oldest first.
  final List<DepotDividendEvent> events;

  const DepotDividendAsset({
    required this.key,
    required this.symbol,
    required this.currency,
    required this.fxCurrency,
    required this.fxRate,
    required this.fetchedAt,
    this.nextExDate,
    this.nextPayDate,
    this.events = const [],
  });

  factory DepotDividendAsset.fromMap(
    Map<String, Object?> map,
    List<DepotDividendEvent> events,
  ) {
    DateTime? date(Object? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
    return DepotDividendAsset(
      key: map['key'] as String,
      symbol: map['symbol'] as String?,
      currency: map['currency'] as String,
      fxCurrency: map['fx_currency'] as String,
      fxRate: map['fx_rate'] as double,
      nextExDate: date(map['next_ex_date']),
      nextPayDate: date(map['next_pay_date']),
      fetchedAt: date(map['fetched_at'])!,
      events: events,
    );
  }

  Map<String, Object?> toMap() => {
    'key': key,
    'symbol': symbol,
    'currency': currency,
    'fx_currency': fxCurrency,
    'fx_rate': fxRate,
    'next_ex_date': nextExDate?.millisecondsSinceEpoch,
    'next_pay_date': nextPayDate?.millisecondsSinceEpoch,
    'fetched_at': fetchedAt.millisecondsSinceEpoch,
  };
}

import '../models/depot_activity.dart';

/// Reads the transaction kind off the document headline. Dividend wins over
/// sale and sale over purchase, because "Verkauf" contains "kauf" and a
/// dividend advice can mention both.
class ActivityTypeParser {
  ActivityTypeParser._();

  static final RegExp _dividend = RegExp(
    r'dividendengutschrift|ertragsgutschrift|aussch(ü|ue)ttung|ertragsabrechnung'
    r'|gutschrift von investmenterträgen',
  );
  static final RegExp _sell = RegExp(
    r'wertpapierverkauf|\bverkauf\b|r(ü|ue)cknahme investmentfonds'
    r'|r(ü|ue)ckzahlung|einl(ö|oe)sung',
  );
  static final RegExp _buy = RegExp(
    r'wertpapierkauf|\bkauf\b|sparplanausf(ü|ue)hrung|einmalanlage',
  );

  static DepotActivityType? parse(String rawText) {
    final lower = rawText.toLowerCase();
    if (_dividend.hasMatch(lower)) return DepotActivityType.dividend;
    if (_sell.hasMatch(lower)) return DepotActivityType.sell;
    if (_buy.hasMatch(lower)) return DepotActivityType.buy;
    return null;
  }
}

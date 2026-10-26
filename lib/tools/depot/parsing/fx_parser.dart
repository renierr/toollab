import 'german_format.dart';
import 'statement_text.dart';

/// `1 [base] = rate [quote]`, as printed in the document. Everything stays
/// offline: the statement always carries the rate it settled at, so no rate
/// service is ever consulted.
class FxRate {
  final double rate;
  final String base;
  final String? quote;

  const FxRate(this.rate, this.base, this.quote);

  /// Units of [currency] per 1 EUR.
  double perEur(String currency) {
    if (quote == 'EUR' && base == currency) return 1 / rate;
    return rate;
  }
}

class FxParser {
  FxParser._();

  static const _labels = ['Devisenkurs', 'Umrechnungskurs', 'Dev.-Kurs'];

  static final RegExp _pair = RegExp(
    r'(?:devisenkurs|umrechnungskurs|dev\.-kurs)[^A-Za-z0-9]{0,4}\(?\s*([A-Z]{3})\s*/\s*([A-Z]{3})',
    caseSensitive: false,
  );

  /// ING writes the rate as `USD = 1,1750` instead of labelling a pair.
  static final RegExp _equals = RegExp(r'\b([A-Z]{3})\s*=\s*([\d.,]+)');

  static FxRate? parse(StatementText text) {
    final labelled = text.numberFor(_labels);
    if (labelled != null && labelled != 0) {
      final pair = _pair.firstMatch(text.raw);
      if (pair == null) return FxRate(labelled, 'EUR', null);
      return FxRate(labelled, pair.group(1)!, pair.group(2));
    }

    final equals = _equals.firstMatch(text.raw);
    if (equals == null) return null;
    final value = GermanFormat.parseNumber(equals.group(2)!);
    if (value == null || value == 0) return null;
    return FxRate(value, 'EUR', equals.group(1));
  }
}

/// A monetary value together with the currency the document printed it in.
class Money {
  final double value;
  final String currency;

  const Money(this.value, this.currency);
}

class GermanFormat {
  GermanFormat._();

  /// `1.234,56` / `1234,5678` / `12` — thousands dots optional, decimal comma
  /// optional. A leading or trailing `-` marks a debit ("1.234,56-"). Letters
  /// on either side disqualify the digits: `IE00B1234567` and `(A1B2C3)` are
  /// identifiers, and reading a `2` out of them is never right. Digits count as
  /// letters here, so skipping one character into an identifier does not let
  /// the rest of it through.
  static final RegExp numberPattern = RegExp(
    r'(?<![A-Za-zÄÖÜäöüß0-9])(-)?(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?(-)?(?![A-Za-zÄÖÜäöüß0-9])',
  );

  static final RegExp datePattern = RegExp(r'\b(\d{2})\.(\d{2})\.(\d{4})\b');

  static final RegExp _currencyPattern = RegExp(r'\b([A-Z]{3})\b');

  static double? parseNumber(String text) {
    final match = numberPattern.firstMatch(text);
    if (match == null) return null;
    return _fromMatch(match);
  }

  /// Typed input, where a dot may be meant as the decimal separator rather
  /// than a thousands separator.
  static double? parseUserNumber(String text) {
    final trimmed = text.trim();
    if (!trimmed.contains(',') && '.'.allMatches(trimmed).length == 1) {
      return parseNumber(trimmed.replaceFirst('.', ','));
    }
    return parseNumber(trimmed);
  }

  static double? _fromMatch(RegExpMatch match) {
    final whole = match.group(2)!.replaceAll('.', '');
    final fraction = match.group(3);
    final raw = fraction == null ? whole : '$whole.$fraction';
    final parsed = double.tryParse(raw);
    if (parsed == null) return null;
    final negative = match.group(1) != null || match.group(4) != null;
    return negative ? -parsed : parsed;
  }

  /// Every number on [text], in order. Used where the interesting value is the
  /// last one on a line ("Provision 1,90- EUR" after a quantity column).
  static List<double> allNumbers(String text) {
    return numberPattern
        .allMatches(text)
        .map(_fromMatch)
        .whereType<double>()
        .toList();
  }

  /// The last amount on [text] with the currency code standing next to it.
  /// German statements put the code either before ("EUR 1.234,56") or after
  /// ("1.234,56 EUR") the number.
  static Money? lastMoney(String text, {String fallbackCurrency = 'EUR'}) {
    final matches = numberPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;
    final match = matches.last;
    final value = _fromMatch(match);
    if (value == null) return null;

    final after = text.substring(match.end);
    final afterCode = _currencyPattern.firstMatch(after);
    if (afterCode != null &&
        after.substring(0, afterCode.start).trim().isEmpty) {
      return Money(value, afterCode.group(1)!);
    }

    final before = text.substring(0, match.start);
    final beforeCodes = _currencyPattern.allMatches(before).toList();
    if (beforeCodes.isNotEmpty) {
      final code = beforeCodes.last;
      if (before.substring(code.end).trim().isEmpty) {
        return Money(value, code.group(1)!);
      }
    }

    return Money(value, fallbackCurrency);
  }

  static DateTime? parseDate(String text) {
    final match = datePattern.firstMatch(text);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}

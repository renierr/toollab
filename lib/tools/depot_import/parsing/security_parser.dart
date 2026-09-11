import 'statement_text.dart';

/// ISIN, WKN and the security name printed next to them.
class SecurityParser {
  SecurityParser._();

  static final RegExp _isin = RegExp(r'\b([A-Z]{2}[A-Z0-9]{9}[0-9])\b');
  static final RegExp _wkn = RegExp(
    r'WKN[:\s]+([A-Z0-9]{6})\b',
    caseSensitive: false,
  );
  static final RegExp _identifierWords = RegExp(
    r'\b(WKN|ISIN)\b[:\s]*',
    caseSensitive: false,
  );
  static final RegExp _leadingQuantity = RegExp(
    r'^\s*(Nominale\s+)?(Stück|Stk\.?|St\.|Nennwert|Anteile)\s+[\d.,]+\s*',
    caseSensitive: false,
  );

  static String isin(String rawText) =>
      _isin.firstMatch(rawText)?.group(1) ?? '';

  static String? wkn(String rawText) => _wkn.firstMatch(rawText)?.group(1);

  /// The name shares a line with the ISIN in every layout seen so far; when
  /// stripping the identifiers leaves nothing, the line above carries it.
  static String name(StatementText text, String isin) {
    if (isin.isEmpty) return '';
    for (int i = 0; i < text.lines.length; i++) {
      if (!text.lines[i].contains(isin)) continue;
      final stripped = text.lines[i]
          .replaceAll(isin, '')
          .replaceAll(_identifierWords, '')
          .replaceFirst(_leadingQuantity, '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (stripped.length > 3) return stripped;
      return i > 0 ? text.lines[i - 1] : '';
    }
    return '';
  }
}

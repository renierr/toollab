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

  /// DKB prints the WKN unlabelled, in brackets behind the ISIN. Requiring a
  /// digit keeps a bracketed word in a security name from being taken for one.
  static final RegExp _bracketWkn = RegExp(r'\(([A-Z0-9]{6})\)');

  static final RegExp _leadingLabel = RegExp(
    r'^\s*(Gattungsbezeichnung|Wertpapierbezeichnung|Bezeichnung|Wertpapier)\s+',
    caseSensitive: false,
  );

  static String isin(String rawText) =>
      _isin.firstMatch(rawText)?.group(1) ?? '';

  static final RegExp _isinFormat = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');

  /// ISO 6166 check digit: letters count as A=10 through Z=35, then the
  /// digit string must pass Luhn. Catches a transposed or misread character
  /// that still matches the ISIN shape.
  static bool isValidIsin(String code) {
    if (!_isinFormat.hasMatch(code)) return false;
    final digits = StringBuffer();
    for (final unit in code.codeUnits) {
      if (unit >= 48 && unit <= 57) {
        digits.writeCharCode(unit);
      } else {
        digits.write((unit - 55).toString());
      }
    }
    var sum = 0;
    final chars = digits.toString();
    for (var i = 0; i < chars.length; i++) {
      var n = chars.codeUnitAt(chars.length - 1 - i) - 48;
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    return sum % 10 == 0;
  }

  static String? wkn(String rawText) {
    final labelled = _wkn.firstMatch(rawText)?.group(1);
    if (labelled != null) return labelled;
    final code = isin(rawText);
    if (code.isEmpty) return null;
    for (final line in rawText.split('\n')) {
      if (!line.contains(code)) continue;
      for (final match in _bracketWkn.allMatches(line)) {
        if (_looksLikeWkn(match.group(1)!)) return match.group(1);
      }
      return null;
    }
    return null;
  }

  static bool _looksLikeWkn(String code) => code.contains(RegExp(r'\d'));

  /// DKB puts the name on the ISIN line; ING gives the ISIN a line of its own
  /// and labels the name below it. So: the ISIN line first, then whatever a
  /// "Wertpapierbezeichnung" label introduces, then the neighbouring lines.
  static String name(StatementText text, String isin) {
    if (isin.isEmpty) return '';
    final index = text.lines.indexWhere((line) => line.contains(isin));
    if (index < 0) return '';

    final stripped = _clean(text.lines[index].replaceAll(isin, ''));
    if (stripped.length > 3) return stripped;

    final labelled = _labelledName(text);
    if (labelled != null) return labelled;

    for (final neighbour in [index + 1, index - 1]) {
      if (neighbour < 0 || neighbour >= text.lines.length) continue;
      final candidate = _clean(text.lines[neighbour].replaceAll(isin, ''));
      if (candidate.length > 3) return candidate;
    }
    return '';
  }

  static String? _labelledName(StatementText text) {
    for (final line in text.lines) {
      if (!_leadingLabel.hasMatch(line)) continue;
      final cleaned = _clean(line);
      if (cleaned.length > 3) return cleaned;
    }
    return null;
  }

  static String _clean(String line) => line
      .replaceAllMapped(
        _bracketWkn,
        (m) => _looksLikeWkn(m.group(1)!) ? '' : m.group(0)!,
      )
      .replaceAll(_identifierWords, '')
      .replaceFirst(_leadingQuantity, '')
      .replaceFirst(_leadingLabel, '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

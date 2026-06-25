/// Formats a converted numeric value for display, keeping roughly 8 significant
/// digits, trimming trailing zeros, and falling back to scientific notation for
/// extreme magnitudes. Non-finite values render as an em dash.
String formatUnitValue(double value) {
  if (!value.isFinite) return '—';
  if (value == 0) return '0';

  final abs = value.abs();
  if (abs < 1e-6 || abs >= 1e15) {
    return value.toStringAsExponential(4);
  }

  final intDigits = abs >= 1 ? abs.floor().toString().length : 1;
  final decimals = (8 - intDigits).clamp(0, 10);
  var s = value.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Parses user input, tolerating a comma as the decimal separator and
/// surrounding whitespace. Returns `null` for empty or invalid input.
double? parseUnitInput(String raw) {
  final trimmed = raw.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

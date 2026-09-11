import 'german_format.dart';

/// The text of one statement, sliced into lines and searchable by the German
/// labels the brokers print. Extracted PDF text is column-shuffled often
/// enough that a label and its value end up on separate lines, so every lookup
/// falls forward a couple of lines before giving up.
class StatementText {
  final String raw;
  final List<String> lines;
  final List<String> _lower;

  StatementText(this.raw)
    : lines = _split(raw),
      _lower = _split(raw).map((line) => line.toLowerCase()).toList();

  static List<String> _split(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(' ', ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  bool contains(String needle) =>
      _lower.any((l) => l.contains(needle.toLowerCase()));

  bool containsAny(Iterable<String> needles) => needles.any(contains);

  /// Index of the first line carrying one of [labels], or -1.
  int indexOf(
    Iterable<String> labels, {
    Iterable<String> excluding = const [],
  }) {
    for (int i = 0; i < _lower.length; i++) {
      final line = _lower[i];
      if (excluding.any((e) => line.contains(e.toLowerCase()))) continue;
      if (labels.any((label) => line.contains(label.toLowerCase()))) return i;
    }
    return -1;
  }

  /// The text that should carry the value for [labels]: the label line itself,
  /// or the next lines when the label stands alone in its own column.
  String? valueTextFor(
    Iterable<String> labels, {
    Iterable<String> excluding = const [],
    int lookahead = 2,
  }) {
    final index = indexOf(labels, excluding: excluding);
    if (index < 0) return null;

    final labelLine = lines[index];
    final tail = _afterLabel(labelLine, labels);
    if (GermanFormat.numberPattern.hasMatch(tail)) return tail;

    for (int offset = 1; offset <= lookahead; offset++) {
      final next = index + offset;
      if (next >= lines.length) break;
      if (GermanFormat.numberPattern.hasMatch(lines[next])) return lines[next];
    }
    return null;
  }

  static String _afterLabel(String line, Iterable<String> labels) {
    final lower = line.toLowerCase();
    int cut = -1;
    for (final label in labels) {
      final at = lower.indexOf(label.toLowerCase());
      if (at >= 0) {
        final end = at + label.length;
        if (end > cut) cut = end;
      }
    }
    return cut < 0 ? line : line.substring(cut);
  }

  Money? moneyFor(
    Iterable<String> labels, {
    Iterable<String> excluding = const [],
    String fallbackCurrency = 'EUR',
  }) {
    final text = valueTextFor(labels, excluding: excluding);
    if (text == null) return null;
    return GermanFormat.lastMoney(text, fallbackCurrency: fallbackCurrency);
  }

  double? numberFor(
    Iterable<String> labels, {
    Iterable<String> excluding = const [],
  }) {
    final text = valueTextFor(labels, excluding: excluding);
    if (text == null) return null;
    return GermanFormat.parseNumber(text);
  }

  /// The first non-zero money found by trying each label group in order, so a
  /// specific label ("Ausführungskurs") wins over a generic one ("Kurs").
  Money? firstMoneyOf(
    List<List<String>> groups, {
    Iterable<String> excluding = const [],
  }) {
    for (final group in groups) {
      final money = moneyFor(group, excluding: excluding);
      if (money != null && money.value != 0) return money;
    }
    return null;
  }

  DateTime? dateFor(Iterable<String> labels) {
    for (int i = 0; i < _lower.length; i++) {
      if (!labels.any((label) => _lower[i].contains(label.toLowerCase()))) {
        continue;
      }
      for (int offset = 0; offset <= 2 && i + offset < lines.length; offset++) {
        final date = GermanFormat.parseDate(lines[i + offset]);
        if (date != null) return date;
      }
    }
    return null;
  }

  /// Sums every line carrying one of [labels]. Each line counts once, so a
  /// statement listing both a per-item and a total row is not double counted
  /// when the labels overlap.
  double sumOf(
    Iterable<String> labels, {
    Iterable<String> excluding = const [],
  }) {
    final seen = <int>{};
    double total = 0;
    for (int i = 0; i < _lower.length; i++) {
      final line = _lower[i];
      if (excluding.any((e) => line.contains(e.toLowerCase()))) continue;
      if (!labels.any((label) => line.contains(label.toLowerCase()))) continue;
      if (!seen.add(i)) continue;
      final value = _valueNear(i, labels, seen);
      if (value != null) total += value.value.abs();
    }
    return total;
  }

  /// The money belonging to the label on [index] — on the label line itself,
  /// or on one of the next lines when the statement is laid out in columns.
  /// Consumed line indices go into [seen] so the same figure is not summed
  /// twice by two labels.
  Money? _valueNear(int index, Iterable<String> labels, Set<int> seen) {
    final tail = _afterLabel(lines[index], labels);
    if (GermanFormat.numberPattern.hasMatch(tail)) {
      return GermanFormat.lastMoney(tail);
    }
    for (int offset = 1; offset <= 2; offset++) {
      final next = index + offset;
      if (next >= lines.length) break;
      if (labels.any((label) => _lower[next].contains(label.toLowerCase()))) {
        break;
      }
      if (!GermanFormat.numberPattern.hasMatch(lines[next])) continue;
      if (!seen.add(next)) break;
      return GermanFormat.lastMoney(lines[next]);
    }
    return null;
  }

  /// Same as [sumOf] but keeps the currency of the first summed line, so a
  /// foreign-currency fee block can be converted afterwards.
  String currencyOf(Iterable<String> labels, {String fallback = 'EUR'}) {
    final text = valueTextFor(labels);
    if (text == null) return fallback;
    return GermanFormat.lastMoney(text, fallbackCurrency: fallback)?.currency ??
        fallback;
  }
}

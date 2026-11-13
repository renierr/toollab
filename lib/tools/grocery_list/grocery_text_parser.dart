import 'package:flutter/foundation.dart';

/// An item suggestion read from speech or a receipt, before it is saved.
@immutable
class GroceryDraft {
  final String name;
  final double amount;
  final String unit;

  const GroceryDraft(this.name, {this.amount = 1, this.unit = 'pcs'});

  @override
  bool operator ==(Object other) =>
      other is GroceryDraft &&
      other.name == name &&
      other.amount == amount &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(name, amount, unit);

  @override
  String toString() => '$amount $unit $name';
}

/// Turns dictated lists and receipt OCR text into [GroceryDraft]s (de/en).
class GroceryTextParser {
  GroceryTextParser._();

  static const units = ['pcs', 'kg', 'g', 'lb', 'oz', 'L', 'ml', 'box', 'pack'];

  static const Map<String, double> _numberWords = {
    'ein': 1,
    'eine': 1,
    'einen': 1,
    'einem': 1,
    'a': 1,
    'an': 1,
    'one': 1,
    'zwei': 2,
    'two': 2,
    'drei': 3,
    'three': 3,
    'vier': 4,
    'four': 4,
    'fünf': 5,
    'five': 5,
    'sechs': 6,
    'six': 6,
    'sieben': 7,
    'seven': 7,
    'acht': 8,
    'eight': 8,
    'neun': 9,
    'nine': 9,
    'zehn': 10,
    'ten': 10,
    'elf': 11,
    'eleven': 11,
    'zwölf': 12,
    'twelve': 12,
    'dutzend': 12,
    'dozen': 12,
    'halbes': 0.5,
    'halbe': 0.5,
    'half': 0.5,
  };

  static const Map<String, String> _unitWords = {
    'kg': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'kilogramm': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'g': 'g',
    'gramm': 'g',
    'gram': 'g',
    'grams': 'g',
    'l': 'L',
    'liter': 'L',
    'litre': 'L',
    'liters': 'L',
    'litres': 'L',
    'ml': 'ml',
    'milliliter': 'ml',
    'millilitre': 'ml',
    'lb': 'lb',
    'lbs': 'lb',
    'pound': 'lb',
    'pounds': 'lb',
    'pfund': 'lb',
    'oz': 'oz',
    'ounce': 'oz',
    'ounces': 'oz',
    'packung': 'pack',
    'packungen': 'pack',
    'pack': 'pack',
    'packs': 'pack',
    'päckchen': 'pack',
    'packet': 'pack',
    'packets': 'pack',
    'box': 'box',
    'boxes': 'box',
    'karton': 'box',
    'kartons': 'box',
    'schachtel': 'box',
    'schachteln': 'box',
    'stück': 'pcs',
    'stk': 'pcs',
    'pcs': 'pcs',
    'piece': 'pcs',
    'pieces': 'pcs',
  };

  static final RegExp _listSplitter = RegExp(
    r'\s*(?:,|;|\n|\bund\b|\band\b|\bsowie\b|\bplus\b)\s*',
    caseSensitive: false,
  );

  static List<GroceryDraft> parseSpoken(String text) {
    final drafts = <GroceryDraft>[];
    for (final part in text.split(_listSplitter)) {
      final draft = _parseItem(part);
      if (draft != null) drafts.add(draft);
    }
    return drafts;
  }

  static GroceryDraft? _parseItem(String raw) {
    final words = raw
        .trim()
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    var amount = 1.0;
    var unit = 'pcs';
    final first = words.first.toLowerCase();
    final number = double.tryParse(first.replaceAll(',', '.'));
    if (number != null && number > 0) {
      amount = number;
      words.removeAt(0);
    } else if (_numberWords.containsKey(first) && words.length > 1) {
      amount = _numberWords[first]!;
      words.removeAt(0);
    }
    if (words.length > 1) {
      final candidate = _unitWords[words.first.toLowerCase()];
      if (candidate != null) {
        unit = candidate;
        words.removeAt(0);
        if (const {'of', 'an'}.contains(words.first.toLowerCase()) &&
            words.length > 1) {
          words.removeAt(0);
        }
      }
    }
    final name = _capitalize(words.join(' '));
    if (!RegExp(r'\p{L}{2}', unicode: true).hasMatch(name)) return null;
    return GroceryDraft(name, amount: amount, unit: unit);
  }

  static final RegExp _price = RegExp(
    r'\s+-?\d{1,4}[.,]\s?\d{2}(?:\s*(?:€|eur|[a-z]|\*))*\s*$',
    caseSensitive: false,
  );
  static final RegExp _quantityPrefix = RegExp(
    r'^(\d{1,3})\s*[x×*]\s+',
    caseSensitive: false,
  );
  static final RegExp _articleCode = RegExp(r'^\d{4,}\s+');
  static final RegExp _skip = RegExp(
    r'summe|gesamt|total|zwischen|mwst|ust\b|steuer|netto|brutto|\bbar\b|'
    r'\bec\b|karte|card|visa|master|wechselgeld|gegeben|zahlung|'
    r'payment|change|cash|pfand|r(?:ü|ue|u)ckgeld|zur(?:ü|ue)ck|rabatt|discount|coupon|\btse\b|beleg|kasse|'
    r'datum|uhrzeit|\bbon\b|filiale|\btel\b|eur/kg|€/kg|/kg\b|danke|thank',
    caseSensitive: false,
  );

  /// Lines with a trailing price are items; totals, payment and tax are not.
  static List<GroceryDraft> parseReceipt(String text) {
    final drafts = <GroceryDraft>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (!_price.hasMatch(line) || _skip.hasMatch(line)) continue;
      var name = line.replaceFirst(_price, '').trim();
      var amount = 1.0;
      final quantity = _quantityPrefix.firstMatch(name);
      if (quantity != null) {
        amount = double.parse(quantity.group(1)!);
        name = name.substring(quantity.end);
      }
      name = name
          .replaceFirst(_articleCode, '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (!RegExp(r'\p{L}{3}', unicode: true).hasMatch(name)) continue;
      drafts.add(GroceryDraft(_titleCase(name), amount: amount));
    }
    return drafts;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Receipts print in capitals; "BIO VOLLMILCH" reads better as "Bio Vollmilch".
  static String _titleCase(String s) {
    if (s != s.toUpperCase()) return s;
    return s
        .toLowerCase()
        .split(' ')
        .map((w) => w.length < 2 ? w : _capitalize(w))
        .join(' ');
  }
}

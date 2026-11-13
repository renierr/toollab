import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/grocery_list/grocery_receipt_reader.dart';
import 'package:tool_lab/tools/grocery_list/grocery_text_parser.dart';

void main() {
  test('reads the JSON array from a model reply', () {
    const reply = '''Here you go:
```json
[{"name": "Vollmilch", "amount": 2, "unit": "L"},
 {"name": "Bananen", "amount": 0, "unit": "bunch"},
 {"name": ""}]
```''';
    expect(GroceryReceiptReader.parseAiReply(reply), const [
      GroceryDraft('Vollmilch', amount: 2, unit: 'L'),
      GroceryDraft('Bananen'),
    ]);
  });

  test('returns nothing for replies without an array', () {
    expect(GroceryReceiptReader.parseAiReply('Sorry.'), isEmpty);
  });

  test('rebuilds receipt rows from separate name and price columns', () {
    final text = GroceryReceiptReader.joinRows([
      (text: 'BIO VOLLMILCH', box: const Rect.fromLTWH(10, 100, 200, 30)),
      (text: 'BUTTER', box: const Rect.fromLTWH(10, 150, 120, 30)),
      (text: '1, 19 A', box: const Rect.fromLTWH(400, 104, 80, 28)),
      (text: '2,29 B', box: const Rect.fromLTWH(400, 148, 80, 30)),
    ]);
    expect(text, 'BIO VOLLMILCH  1, 19 A\nBUTTER  2,29 B');
    expect(GroceryTextParser.parseReceipt(text), const [
      GroceryDraft('Bio Vollmilch'),
      GroceryDraft('Butter'),
    ]);
  });
}

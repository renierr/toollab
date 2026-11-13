import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/grocery_list/grocery_text_parser.dart';

void main() {
  group('parseSpoken', () {
    test('splits German lists and reads amounts and units', () {
      expect(
        GroceryTextParser.parseSpoken(
          'zwei Liter Milch, 500 Gramm Hackfleisch und Brot',
        ),
        const [
          GroceryDraft('Milch', amount: 2, unit: 'L'),
          GroceryDraft('Hackfleisch', amount: 500, unit: 'g'),
          GroceryDraft('Brot'),
        ],
      );
    });

    test('reads English lists', () {
      expect(
        GroceryTextParser.parseSpoken('a pack of eggs and three apples.'),
        const [
          GroceryDraft('Eggs', unit: 'pack'),
          GroceryDraft('Apples', amount: 3),
        ],
      );
    });

    test('keeps a lone number word as the name', () {
      expect(GroceryTextParser.parseSpoken('Eine'), const [
        GroceryDraft('Eine'),
      ]);
    });
  });

  group('parseReceipt', () {
    test('keeps priced lines and skips totals and payment', () {
      const receipt = '''
REWE Markt GmbH
BIO VOLLMILCH 3,8%      1,19 A
2 x BANANEN              2,58 A
4008400401621 BUTTER     2,29 B
Pfand                    0,25 A
SUMME EUR                6,31
Geg. BAR                10,00
Rückgeld                 3,69
Rueckgeld                1,20
MwSt 7%                  0,41
''';
      expect(GroceryTextParser.parseReceipt(receipt), const [
        GroceryDraft('Bio Vollmilch 3,8%'),
        GroceryDraft('Bananen', amount: 2),
        GroceryDraft('Butter'),
      ]);
    });
  });
}

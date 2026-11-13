import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/translator/translator_ocr.dart';

void main() {
  group('TranslatorOcr.joinBlocks', () {
    test('joins the lines of a block and keeps blocks apart', () {
      expect(
        TranslatorOcr.joinBlocks([
          ['Bitte nicht', 'rauchen'],
          ['Ausgang'],
        ]),
        'Bitte nicht rauchen\nAusgang',
      );
    });

    test('rejoins words hyphenated at a line end', () {
      expect(
        TranslatorOcr.joinBlocks([
          ['Die Bahnsteig-', 'kante freihalten'],
        ]),
        'Die Bahnsteigkante freihalten',
      );
    });

    test('keeps the hyphen of a compound split at a line end', () {
      expect(
        TranslatorOcr.joinBlocks([
          ['Nord-', 'Süd-Verbindung'],
        ]),
        'Nord-Süd-Verbindung',
      );
    });

    test('keeps a dash between spaces', () {
      expect(
        TranslatorOcr.joinBlocks([
          ['Montag -', 'Freitag'],
        ]),
        'Montag - Freitag',
      );
    });

    test('drops empty lines and blocks', () {
      expect(
        TranslatorOcr.joinBlocks([
          ['  ', 'Hello'],
          [],
          ['World'],
        ]),
        'Hello\nWorld',
      );
    });
  });
}

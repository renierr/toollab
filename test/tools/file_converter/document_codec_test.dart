import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/file_converter/converters/document_codec.dart';
import 'package:tool_lab/tools/file_converter/doc_format.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));
String _str(Uint8List b) => utf8.decode(b);

const _markdown = '''
# Title

Some **bold** and *italic* text.

- one
- two

| A | B |
|---|---|
| 1 | 2 |
''';

void main() {
  group('DocFormat', () {
    test('detects format from extension', () {
      expect(DocFormat.fromPath('a.docx'), DocFormat.docx);
      expect(DocFormat.fromPath('a.MD'), DocFormat.md);
      expect(DocFormat.fromPath('a.markdown'), DocFormat.md);
      expect(DocFormat.fromPath('a.htm'), DocFormat.html);
      expect(DocFormat.fromPath('a.bin'), isNull);
    });
  });

  group('targetsFor', () {
    test('excludes the source format and lists encodable targets', () {
      final targets = DocumentConverter.targetsFor(DocFormat.md);
      expect(targets, isNot(contains(DocFormat.md)));
      expect(
        targets,
        containsAll([
          DocFormat.html,
          DocFormat.pdf,
          DocFormat.docx,
          DocFormat.txt,
        ]),
      );
    });
  });

  group('conversions produce non-empty output', () {
    test('markdown -> html keeps heading text', () async {
      final out = await DocumentConverter.convert(
        _bytes(_markdown),
        DocFormat.md,
        DocFormat.html,
      );
      final html = _str(out);
      expect(html.toLowerCase(), contains('<h1'));
      expect(html, contains('Title'));
    });

    test('markdown -> docx yields a non-empty zip (PK header)', () async {
      final out = await DocumentConverter.convert(
        _bytes(_markdown),
        DocFormat.md,
        DocFormat.docx,
      );
      expect(out.length, greaterThan(100));
      expect(out[0], 0x50); // 'P'
      expect(out[1], 0x4B); // 'K'
    });

    test('markdown -> pdf yields a non-empty %PDF', () async {
      final out = await DocumentConverter.convert(
        _bytes(_markdown),
        DocFormat.md,
        DocFormat.pdf,
      );
      expect(out.length, greaterThan(100));
      expect(_str(out.sublist(0, 4)), '%PDF');
    });

    test('markdown -> docx -> markdown round-trips the title', () async {
      final docx = await DocumentConverter.convert(
        _bytes(_markdown),
        DocFormat.md,
        DocFormat.docx,
      );
      final md = await DocumentConverter.convert(
        docx,
        DocFormat.docx,
        DocFormat.md,
      );
      expect(_str(md), contains('Title'));
    });

    test('txt -> txt preserves text', () async {
      final out = await DocumentConverter.convert(
        _bytes('hello\nworld'),
        DocFormat.txt,
        DocFormat.html,
      );
      final html = _str(out);
      expect(html, contains('hello'));
      expect(html, contains('world'));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:html2md/html2md.dart' as html2md;

import '../doc_format.dart';

/// Hub-and-spoke document codec.
///
/// Every supported format decodes into a [DocxBuiltDocument] (the intermediate
/// representation) and/or encodes from it. A conversion `A -> B` is therefore
/// `decode[A]` followed by `encode[B]`, so N+M codecs cover every N*M pair.
abstract class DocumentCodec {
  DocFormat get format;

  /// Whether this format can be parsed into the intermediate representation.
  bool get canDecode;

  /// Whether the intermediate representation can be serialized to this format.
  bool get canEncode;

  Future<DocxBuiltDocument> decode(Uint8List input);

  Future<Uint8List> encode(DocxBuiltDocument doc);
}

class _DocxCodec extends DocumentCodec {
  @override
  DocFormat get format => DocFormat.docx;
  @override
  bool get canDecode => true;
  @override
  bool get canEncode => true;

  @override
  Future<DocxBuiltDocument> decode(Uint8List input) =>
      DocxReader.loadFromBytes(input);

  @override
  Future<Uint8List> encode(DocxBuiltDocument doc) =>
      DocxExporter().exportToBytes(doc);
}

class _HtmlCodec extends DocumentCodec {
  @override
  DocFormat get format => DocFormat.html;
  @override
  bool get canDecode => true;
  @override
  bool get canEncode => true;

  @override
  Future<DocxBuiltDocument> decode(Uint8List input) async {
    final html = utf8.decode(input, allowMalformed: true);
    return DocxBuiltDocument(elements: await DocxParser.fromHtml(html));
  }

  @override
  Future<Uint8List> encode(DocxBuiltDocument doc) async =>
      Uint8List.fromList(utf8.encode(HtmlExporter().export(doc)));
}

class _MarkdownCodec extends DocumentCodec {
  @override
  DocFormat get format => DocFormat.md;
  @override
  bool get canDecode => true;
  @override
  bool get canEncode => true;

  @override
  Future<DocxBuiltDocument> decode(Uint8List input) async {
    final markdown = utf8.decode(input, allowMalformed: true);
    return DocxBuiltDocument(elements: await DocxParser.fromMarkdown(markdown));
  }

  @override
  Future<Uint8List> encode(DocxBuiltDocument doc) async {
    // No native Markdown writer: serialize to HTML, then HTML -> Markdown.
    final markdown = html2md.convert(HtmlExporter().export(doc));
    return Uint8List.fromList(utf8.encode(markdown));
  }
}

class _PdfCodec extends DocumentCodec {
  @override
  DocFormat get format => DocFormat.pdf;
  @override
  bool get canDecode => true;
  @override
  bool get canEncode => true;

  @override
  Future<DocxBuiltDocument> decode(Uint8List input) async {
    final pdf = await PdfReader.loadFromBytes(input);
    return pdf.toDocx();
  }

  @override
  Future<Uint8List> encode(DocxBuiltDocument doc) async =>
      PdfExporter().exportToBytes(doc);
}

class _TxtCodec extends DocumentCodec {
  @override
  DocFormat get format => DocFormat.txt;
  @override
  bool get canDecode => true;
  @override
  bool get canEncode => true;

  @override
  Future<DocxBuiltDocument> decode(Uint8List input) async {
    final text = utf8.decode(input, allowMalformed: true);
    final elements = <DocxNode>[
      for (final line in text.split('\n'))
        DocxParagraph.text(line.replaceAll('\r', '')),
    ];
    return DocxBuiltDocument(elements: elements);
  }

  @override
  Future<Uint8List> encode(DocxBuiltDocument doc) async {
    final buffer = StringBuffer();
    for (final node in doc.elements) {
      _writeNode(node, buffer);
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  void _writeNode(DocxNode node, StringBuffer buffer) {
    if (node is DocxParagraph) {
      _writeInlines(node.children, buffer);
      buffer.writeln();
    } else if (node is DocxList) {
      for (final item in node.items) {
        _writeInlines(item.children, buffer);
        buffer.writeln();
      }
    } else if (node is DocxTable) {
      for (final row in node.rows) {
        final cells = <String>[];
        for (final cell in row.cells) {
          final cellBuffer = StringBuffer();
          for (final child in cell.children) {
            _writeNode(child, cellBuffer);
          }
          cells.add(cellBuffer.toString().trim());
        }
        buffer.writeln(cells.join('\t'));
      }
    }
  }

  void _writeInlines(List<DocxInline> inlines, StringBuffer buffer) {
    for (final inline in inlines) {
      if (inline is DocxText) {
        buffer.write(inline.content);
      } else if (inline is DocxLineBreak) {
        buffer.write('\n');
      }
    }
  }
}

/// Registry and entry point for document conversion.
class DocumentConverter {
  DocumentConverter._();

  static final List<DocumentCodec> _codecs = [
    _DocxCodec(),
    _PdfCodec(),
    _HtmlCodec(),
    _MarkdownCodec(),
    _TxtCodec(),
  ];

  static DocumentCodec? _codecFor(DocFormat format) {
    for (final codec in _codecs) {
      if (codec.format == format) return codec;
    }
    return null;
  }

  static bool canDecode(DocFormat format) =>
      _codecFor(format)?.canDecode ?? false;

  /// Formats that [from] can be converted into, given current codec support.
  static List<DocFormat> targetsFor(DocFormat from) {
    if (!canDecode(from)) return const [];
    return _codecs
        .where((codec) => codec.canEncode && codec.format != from)
        .map((codec) => codec.format)
        .toList();
  }

  static Future<Uint8List> convert(
    Uint8List bytes,
    DocFormat from,
    DocFormat to,
  ) async {
    final decoder = _codecFor(from);
    final encoder = _codecFor(to);
    if (decoder == null || !decoder.canDecode) {
      throw UnsupportedError('Cannot read ${from.name} files');
    }
    if (encoder == null || !encoder.canEncode) {
      throw UnsupportedError('Cannot write ${to.name} files');
    }
    final ir = await decoder.decode(bytes);
    return encoder.encode(ir);
  }
}

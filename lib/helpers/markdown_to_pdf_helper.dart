import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MarkdownToPdfConverter {
  static pw.Font? _bodyFont;
  static pw.Font? _boldFont;
  static pw.Font? _italicFont;
  static pw.Font? _monoFont;
  static pw.Font? _emojiFont;

  static Future<void> _ensureFonts() async {
    if (_bodyFont != null) return;
    _bodyFont = await _loadFont('NotoSans-Regular');
    _boldFont = await _loadFont('NotoSans-Bold');
    _italicFont = await _loadFont('NotoSans-Italic');
    _monoFont = await _loadFont('NotoSansMono-Regular');
    _emojiFont = await _loadFont('NotoColorEmoji');
  }

  static Future<pw.Font> _loadFont(String name) async {
    final data = await rootBundle.load('assets/google_fonts/$name.ttf');
    return pw.TtfFont(data);
  }

  static Future<Uint8List> convert({
    required String markdown,
    String? title,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    await _ensureFonts();

    final doc = pw.Document();
    final parser = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    final ast = parser.parse(markdown);

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 64, vertical: 56),
        header: (context) {
          if (title == null) return pw.SizedBox.shrink();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              _clean(title),
              style: pw.TextStyle(
                font: _bodyFont,
                fontSize: 9,
                color: PdfColors.grey600,
                fontFallback: [_emojiFont!],
              ),
            ),
          );
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: pw.TextStyle(
              font: _bodyFont,
              fontSize: 9,
              color: PdfColors.grey600,
              fontFallback: [_emojiFont!],
            ),
          ),
        ),
        build: (_) => _buildBlocks(ast),
      ),
    );

    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }

  static pw.TextStyle _baseStyle() =>
      pw.TextStyle(font: _bodyFont, fontSize: 11, fontFallback: [_emojiFont!]);

  static pw.TextStyle _boldStyle({double? size}) => pw.TextStyle(
    font: _boldFont,
    fontSize: size ?? 11,
    fontFallback: [_emojiFont!],
  );

  static pw.TextStyle _italicStyle({double? size}) => pw.TextStyle(
    font: _italicFont,
    fontSize: size ?? 11,
    fontFallback: [_emojiFont!],
  );

  static pw.TextStyle _monoStyle() => pw.TextStyle(
    font: _monoFont,
    fontSize: 9,
    color: PdfColors.grey800,
    fontFallback: [_emojiFont!],
  );

  static pw.TextStyle _fallbackStyle() =>
      pw.TextStyle(fontFallback: [_emojiFont!]);

  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[\u200c\u200d\ufe0e\ufe0f]'), '');

  static List<pw.Widget> _buildBlocks(List<md.Node> nodes) {
    final widgets = <pw.Widget>[];
    for (final node in nodes) {
      final block = _buildBlock(node);
      if (block != null) widgets.add(block);
    }
    return widgets;
  }

  static pw.Widget? _buildBlock(md.Node node) {
    if (node is! md.Element) return null;
    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _buildHeader(node);
      case 'p':
        return _buildParagraph(node);
      case 'blockquote':
        return _buildBlockquote(node);
      case 'ul':
        return _buildUnorderedList(node);
      case 'ol':
        return _buildOrderedList(node);
      case 'pre':
        return _buildCodeBlock(node);
      case 'hr':
        return pw.Column(
          children: [
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),
          ],
        );
      default:
        return null;
    }
  }

  static int _headerLevel(String tag) => int.parse(tag[1]);

  static pw.Widget _buildHeader(md.Element element) {
    final level = _headerLevel(element.tag);
    final sizes = [24, 20, 16, 14, 12, 11];
    final size = sizes[(level - 1).clamp(0, 5)];
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: level == 1 ? 0 : 12, bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          style: _boldStyle(size: size.toDouble()),
          children: _buildInlineSpans(element.children ?? []),
        ),
      ),
    );
  }

  static pw.Widget _buildParagraph(md.Element element) {
    final children = element.children;
    if (children == null || children.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          style: _baseStyle(),
          children: _buildInlineSpans(children),
        ),
      ),
    );
  }

  static pw.Widget _buildBlockquote(md.Element element) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(left: 14, top: 4, bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey400, width: 3),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _buildBlocks(element.children ?? []),
      ),
    );
  }

  static pw.Widget _buildUnorderedList(md.Element element) {
    final items = element.children ?? [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((item) {
        if (item is md.Element && item.tag == 'li') {
          return _buildListItem(item, prefix: '\u2022');
        }
        return pw.SizedBox.shrink();
      }).toList(),
    );
  }

  static pw.Widget _buildOrderedList(md.Element element) {
    final items = element.children ?? [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        final item = items[i];
        if (item is md.Element && item.tag == 'li') {
          return _buildListItem(item, prefix: '${i + 1}.');
        }
        return pw.SizedBox.shrink();
      }),
    );
  }

  static bool? _checkboxChecked(md.Element item) {
    final children = item.children;
    if (children == null || children.isEmpty) return null;
    final first = children.first;
    if (first is md.Element &&
        first.tag == 'input' &&
        first.attributes['type'] == 'checkbox') {
      return first.attributes.containsKey('checked');
    }
    if (first is md.Element && first.tag == 'p') {
      final p = first.children;
      if (p != null &&
          p.isNotEmpty &&
          p.first is md.Element &&
          (p.first as md.Element).tag == 'input' &&
          (p.first as md.Element).attributes['type'] == 'checkbox') {
        return (p.first as md.Element).attributes.containsKey('checked');
      }
    }
    return null;
  }

  static List<md.Node> _stripCheckbox(List<md.Node> children) {
    if (children.isEmpty) return children;
    final first = children.first;
    if (first is md.Element &&
        first.tag == 'input' &&
        first.attributes['type'] == 'checkbox') {
      return children.sublist(1);
    }
    if (first is md.Element && first.tag == 'p') {
      final p = first.children;
      if (p != null &&
          p.isNotEmpty &&
          p.first is md.Element &&
          (p.first as md.Element).tag == 'input' &&
          (p.first as md.Element).attributes['type'] == 'checkbox') {
        final rest = [md.Element('p', p.sublist(1)), ...children.sublist(1)];
        return rest;
      }
    }
    return children;
  }

  static pw.Widget _buildCheckboxWidget(bool checked) {
    final size = 7.0;
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
        color: checked ? PdfColors.grey700 : null,
      ),
    );
  }

  static pw.Widget _prefixWidget(
    String text, {
    required bool isCheckbox,
    required bool checked,
  }) {
    if (isCheckbox) return _buildCheckboxWidget(checked);
    return pw.Text(text, style: _baseStyle().copyWith(fontSize: 11));
  }

  static pw.Widget _buildListItem(md.Element item, {required String prefix}) {
    var children = item.children ?? [];
    final checked = _checkboxChecked(item);
    final isCheckbox = checked != null;
    if (isCheckbox) children = _stripCheckbox(children);
    if (children.isEmpty) return pw.SizedBox.shrink();

    final onlyElems = children.every((c) => c is md.Element && c is! md.Text);
    final onlyInline = children.every(
      (c) => c is md.Text || (c is md.Element && !_isBlockTag(c.tag)),
    );

    if (onlyElems && children.length == 1) {
      final child = children.first as md.Element;
      if (child.tag == 'p') {
        final paraChildren = child.children ?? [];
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 22,
                child: _prefixWidget(
                  prefix,
                  isCheckbox: isCheckbox,
                  checked: checked ?? false,
                ),
              ),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: _baseStyle(),
                    children: _buildInlineSpans(paraChildren),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (onlyInline) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 22,
              child: _prefixWidget(
                prefix,
                isCheckbox: isCheckbox,
                checked: checked ?? false,
              ),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: _baseStyle(),
                  children: _buildInlineSpans(children),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final blocks = <pw.Widget>[];
    for (final child in children) {
      if (child is md.Element && _isBlockTag(child.tag)) {
        final b = _buildBlock(child);
        if (b != null) blocks.add(b);
      } else {
        blocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                style: _baseStyle(),
                children: _buildInlineSpans([child]),
              ),
            ),
          ),
        );
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _prefixWidget(
            prefix,
            isCheckbox: isCheckbox,
            checked: checked ?? false,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 22),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: blocks,
            ),
          ),
        ],
      ),
    );
  }

  static bool _isBlockTag(String tag) {
    return const {
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'p',
      'blockquote',
      'ul',
      'ol',
      'pre',
      'hr',
    }.contains(tag);
  }

  static pw.Widget _buildCodeBlock(md.Element element) {
    final children = element.children;
    String code;
    if (children != null &&
        children.length == 1 &&
        children.first is md.Element &&
        (children.first as md.Element).tag == 'code') {
      code = children.first.textContent;
    } else {
      code = element.textContent;
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        _clean(code),
        style: pw.TextStyle(
          font: _monoFont,
          fontSize: 9,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static List<pw.TextSpan> _buildInlineSpans(List<md.Node> nodes) {
    return nodes.map(_buildInlineSpan).toList();
  }

  static pw.TextSpan _buildInlineSpan(md.Node node) {
    if (node is md.Text) {
      return pw.TextSpan(text: _clean(node.text), style: _fallbackStyle());
    }
    if (node is! md.Element) return const pw.TextSpan(text: '');

    switch (node.tag) {
      case 'strong':
        return pw.TextSpan(
          style: _boldStyle(),
          children: _buildInlineSpans(node.children ?? []),
        );
      case 'em':
        return pw.TextSpan(
          style: _italicStyle(),
          children: _buildInlineSpans(node.children ?? []),
        );
      case 'code':
        return pw.TextSpan(style: _monoStyle(), text: _clean(node.textContent));
      case 'a':
        final href = node.attributes['href'];
        return pw.TextSpan(
          style: pw.TextStyle(
            font: _bodyFont,
            color: PdfColors.blue700,
            decoration: pw.TextDecoration.underline,
            fontFallback: [_emojiFont!],
          ),
          children: [
            ..._buildInlineSpans(node.children ?? []),
            if (href != null && href.isNotEmpty)
              pw.TextSpan(
                text: ' (${_clean(href)})',
                style: pw.TextStyle(
                  font: _bodyFont,
                  fontSize: 9,
                  color: PdfColors.grey500,
                  fontFallback: [_emojiFont!],
                ),
              ),
          ],
        );
      case 'img':
        final alt = node.attributes['alt'] ?? '';
        return pw.TextSpan(
          text: alt.isNotEmpty ? '[Image: ${_clean(alt)}]' : '[Image]',
          style: pw.TextStyle(
            font: _italicFont,
            color: PdfColors.grey500,
            fontFallback: [_emojiFont!],
          ),
        );
      case 'br':
        return const pw.TextSpan(text: '\n');
      case 'del':
        return pw.TextSpan(
          style: pw.TextStyle(
            font: _bodyFont,
            decoration: pw.TextDecoration.lineThrough,
            fontFallback: [_emojiFont!],
          ),
          children: _buildInlineSpans(node.children ?? []),
        );
      default:
        return pw.TextSpan(
          style: _baseStyle(),
          children: _buildInlineSpans(node.children ?? []),
        );
    }
  }
}

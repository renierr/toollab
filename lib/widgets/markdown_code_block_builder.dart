import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tool_lab/widgets/markdown_code_block.dart';

/// Renders `pre` elements as a [MarkdownCodeBlock], keeping the fence info
/// string (`class="language-dart"`) that the default renderer discards.
class MarkdownCodeBlockBuilder extends MarkdownElementBuilder {
  final double scale;

  MarkdownCodeBlockBuilder({required this.scale});

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => null;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return MarkdownCodeBlock(
      code: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
      fenceLanguage: _fenceLanguage(element),
      scale: scale,
    );
  }

  static String? _fenceLanguage(md.Element pre) {
    for (final child in pre.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        final classes = child.attributes['class'];
        if (classes == null) return null;
        for (final cls in classes.split(RegExp(r'\s+'))) {
          if (cls.startsWith('language-')) {
            return cls.substring('language-'.length);
          }
        }
      }
    }
    return null;
  }
}

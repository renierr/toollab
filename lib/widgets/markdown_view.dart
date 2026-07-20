import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/markdown_checkbox.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownView extends StatefulWidget {
  final String data;
  final bool selectable;
  final Color accentColor;
  final double scale;

  const MarkdownView({
    super.key,
    required this.data,
    this.selectable = true,
    this.accentColor = AppTheme.accentBlue,
    this.scale = 1.0,
  });

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView>
    implements MarkdownBuilderDelegate {
  List<Widget>? _children;
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final TapGestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) {
    code = code.replaceAll(RegExp(r'\n$'), '');
    return TextSpan(
      style: styleSheet.code?.copyWith(backgroundColor: Colors.transparent),
      text: code,
    );
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _preprocessAST(List<md.Node> nodes) {
    for (final node in nodes) {
      if (node is md.Element) {
        if (node.tag == 'li') {
          if (node.children != null && node.children!.isNotEmpty) {
            final firstChild = node.children![0];
            if (firstChild is md.Element && firstChild.tag == 'p') {
              if (firstChild.children != null &&
                  firstChild.children!.isNotEmpty) {
                final pFirstChild = firstChild.children![0];
                if (pFirstChild is md.Element &&
                    pFirstChild.tag == 'input' &&
                    pFirstChild.attributes['type'] == 'checkbox') {
                  firstChild.children!.removeAt(0);
                  node.children!.insert(0, pFirstChild);
                }
              }
            }
          }
        }
        if (node.children != null) {
          _preprocessAST(node.children!);
        }
      }
    }
  }

  String _preprocessMarkdown(String markdown) {
    final lines = markdown.split('\n');
    final newLines = <String>[];
    final listRegex = RegExp(r'^\s*([-*+]\s+\[[ xX]\]|[-*+]\s|\d+\.\s)');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        // Find previous non-empty line
        String? prevLine;
        for (int j = i - 1; j >= 0; j--) {
          if (lines[j].trim().isNotEmpty) {
            prevLine = lines[j];
            break;
          }
        }
        // Find next non-empty line
        String? nextLine;
        for (int j = i + 1; j < lines.length; j++) {
          if (lines[j].trim().isNotEmpty) {
            nextLine = lines[j];
            break;
          }
        }

        if (prevLine != null &&
            nextLine != null &&
            listRegex.hasMatch(prevLine) &&
            listRegex.hasMatch(nextLine)) {
          // If this is the first blank line in a block of consecutive blank lines,
          // split the list. Otherwise, render an empty spacing paragraph.
          final bool isFirstBlank = i == 0 || lines[i - 1].trim().isNotEmpty;
          if (isFirstBlank) {
            newLines.add('<!-- -->');
          } else {
            newLines.add('&nbsp;');
          }
          continue;
        }
      }
      newLines.add(line);
    }
    return newLines.join('\n');
  }

  void _parseMarkdown() {
    _disposeRecognizers();

    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    final preprocessed = _preprocessMarkdown(widget.data);
    final List<String> lines = const LineSplitter().convert(preprocessed);
    final List<md.Node> astNodes = document.parseLines(lines);

    // Preprocess AST to fix checkbox rendering inside loose lists
    _preprocessAST(astNodes);

    final theme = Theme.of(context);

    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      textScaler: TextScaler.linear(widget.scale),
      p: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      codeblockPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.0),
      ),
      blockquotePadding: const EdgeInsets.all(12.0),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6.0),
        border: Border(left: BorderSide(color: widget.accentColor, width: 4.0)),
      ),
    );
    final MarkdownBuilder builder = MarkdownBuilder(
      delegate: this,
      selectable: false,
      styleSheet: styleSheet,
      imageDirectory: null,
      imageBuilder: (uri, title, alt) {
        double? width;
        double? height;
        if (alt != null && alt.contains('|')) {
          final parts = alt.split('|');
          final sizePart = parts[1].trim().toLowerCase();

          if (sizePart.contains('x')) {
            final dimensions = sizePart.split('x');
            width = double.tryParse(dimensions[0]);
            height = double.tryParse(dimensions[1]);
          } else {
            width = double.tryParse(sizePart);
          }
        }

        Widget imageWidget;
        final uriStr = uri.toString();

        if (uriStr.startsWith('data:image/')) {
          try {
            final commaIndex = uriStr.indexOf(',');
            if (commaIndex != -1) {
              final base64Data = uriStr.substring(commaIndex + 1);
              final bytes = base64Decode(base64Data);
              imageWidget = Image.memory(bytes, fit: BoxFit.contain);
            } else {
              imageWidget = const Icon(Icons.broken_image);
            }
          } catch (e) {
            imageWidget = const Icon(Icons.broken_image);
          }
        } else {
          imageWidget = Image.network(
            uriStr,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          );
        }

        if (width != null || height != null) {
          return SizedBox(width: width, height: height, child: imageWidget);
        }

        return imageWidget;
      },
      checkboxBuilder: (checked) =>
          MarkdownCheckbox(checked: checked, checkedColor: widget.accentColor),
      bulletBuilder: null,
      builders: const {},
      paddingBuilders: const {},
      fitContent: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
    );

    _children = builder.build(astNodes);
  }

  @override
  void didChangeDependencies() {
    _parseMarkdown();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.scale != oldWidget.scale ||
        widget.accentColor != oldWidget.accentColor) {
      _parseMarkdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_children == null) return const SizedBox();
    Widget markdownWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _children!,
    );

    if (widget.selectable) {
      markdownWidget = SelectionArea(child: markdownWidget);
    }

    return markdownWidget;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../chat_models.dart';

/// Turns DeepSeek's `[citation:N]` markers into `citation` elements.
class CitationSyntax extends md.InlineSyntax {
  static const String tag = 'citation';
  static final CitationSyntax instance = CitationSyntax._();

  CitationSyntax._() : super(r'\[citation:(\d+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(tag, match[1]!));
    return true;
  }
}

class CitationBuilder extends MarkdownElementBuilder {
  final List<ChatCitation> citations;
  final Color color;

  CitationBuilder({required this.citations, required this.color});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final index = int.tryParse(element.textContent);
    if (index == null) return null;
    final citation = citations.where((c) => c.index == index).firstOrNull;
    // Returned as text so the badge stays inline within the paragraph.
    return Text.rich(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _CitationBadge(index: index, citation: citation, color: color),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CitationBuilder &&
      other.color == color &&
      listEquals(other.citations, citations);

  @override
  int get hashCode => Object.hash(color, Object.hashAll(citations));
}

class _CitationBadge extends StatelessWidget {
  final int index;
  final ChatCitation? citation;
  final Color color;

  const _CitationBadge({
    required this.index,
    required this.citation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final citation = this.citation;
    final badge = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        '$index',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (citation == null) return badge;

    final site = citation.siteName.isNotEmpty
        ? citation.siteName
        : Uri.tryParse(citation.url)?.host ?? citation.url;
    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: site,
            style: const TextStyle(fontWeight: FontWeight.w300),
          ),
          if (citation.title.isNotEmpty)
            TextSpan(
              text: '\n${citation.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (citation.snippet.isNotEmpty)
            TextSpan(text: '\n\n${_short(citation.snippet)}'),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(10.0),
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse(citation.url),
            mode: LaunchMode.externalApplication,
          ),
          child: badge,
        ),
      ),
    );
  }

  static String _short(String text) =>
      text.length > 280 ? '${text.substring(0, 277)}…' : text;
}

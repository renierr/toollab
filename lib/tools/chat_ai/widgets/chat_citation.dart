import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat_models.dart';

/// Turns DeepSeek's `[citation:N]` markers into `citation` elements.
class CitationSyntax extends md.InlineSyntax {
  static const String tag = 'citation';
  static const String _pattern = r'\[citation:(\d+)\]';
  static final CitationSyntax instance = CitationSyntax._();

  CitationSyntax._() : super(_pattern);

  /// [text] without its markers, for copying or sharing.
  static String strip(String text) =>
      text.replaceAll(RegExp(r' ?' + _pattern), '');

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

class _CitationBadge extends StatefulWidget {
  final int index;
  final ChatCitation? citation;
  final Color color;

  const _CitationBadge({
    required this.index,
    required this.citation,
    required this.color,
  });

  @override
  State<_CitationBadge> createState() => _CitationBadgeState();
}

class _CitationBadgeState extends State<_CitationBadge> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final citation = widget.citation;
    final badge = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        '${widget.index}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: widget.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (citation == null) return badge;

    // Hover previews the source; a tap or click pins it with a link.
    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        _CitationCard(
          citation: citation,
          color: widget.color,
          onOpen: () {
            _menu.close();
            launchUrl(
              Uri.parse(citation.url),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ],
      child: Tooltip(
        richMessage: _CitationCard.summary(citation, scheme),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(12.0),
        textStyle: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurface,
          height: 1.35,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.3),
              blurRadius: 12.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        waitDuration: const Duration(milliseconds: 250),
        // Touch gets the pinned card on tap; a long-press preview is noise.
        triggerMode: TooltipTriggerMode.manual,
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
          child: badge,
        ),
      ),
    );
  }
}

class _CitationCard extends StatelessWidget {
  final ChatCitation citation;
  final Color color;
  final VoidCallback onOpen;

  const _CitationCard({
    required this.citation,
    required this.color,
    required this.onOpen,
  });

  static String _site(ChatCitation citation) => citation.siteName.isNotEmpty
      ? citation.siteName
      : Uri.tryParse(citation.url)?.host ?? citation.url;

  static String _short(String text) =>
      text.length > 280 ? '${text.substring(0, 277)}…' : text;

  /// The source as one block of text, for the hover preview.
  static TextSpan summary(ChatCitation citation, ColorScheme scheme) =>
      TextSpan(
        children: [
          TextSpan(
            text: _site(citation),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (citation.title.isNotEmpty)
            TextSpan(
              text: '\n${citation.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (citation.snippet.isNotEmpty)
            TextSpan(text: '\n\n${_short(citation.snippet)}'),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14.0, 12.0, 8.0, 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _site(citation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (citation.title.isNotEmpty) ...[
              const SizedBox(height: 2.0),
              Text(
                citation.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (citation.snippet.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Text(
                citation.snippet,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 16.0),
                label: Text(l10n.chatAiOpenWebsite),
                style: TextButton.styleFrom(foregroundColor: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

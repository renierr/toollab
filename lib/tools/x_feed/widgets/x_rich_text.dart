import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import '../models/x_post.dart';

/// Post text with tappable links, @mentions and #hashtags.
class XRichText extends StatefulWidget {
  final String text;
  final List<XLink> links;
  final TextStyle? style;
  final int? maxLines;
  final ValueChanged<String> onLink;
  final ValueChanged<String> onMention;
  final ValueChanged<String> onHashtag;

  const XRichText({
    super.key,
    required this.text,
    required this.links,
    required this.onLink,
    required this.onMention,
    required this.onHashtag,
    this.style,
    this.maxLines,
  });

  @override
  State<XRichText> createState() => _XRichTextState();
}

class _XRichTextState extends State<XRichText> with DisposeCleanup {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    onDispose(_disposeRecognizers);
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _recognizer(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  List<InlineSpan> _spans(Color linkColor) {
    _disposeRecognizers();
    final text = widget.text;
    final linkByDisplay = {for (final l in widget.links) l.display: l.url};
    final parts = [
      ...linkByDisplay.keys.map(RegExp.escape),
      r'https?://\S+',
      r'@\w{1,15}',
      r'#[\p{L}\p{N}_]+',
    ];
    final pattern = RegExp(parts.join('|'), unicode: true);
    final linkStyle = TextStyle(color: linkColor);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      final VoidCallback onTap;
      if (linkByDisplay.containsKey(token)) {
        onTap = () => widget.onLink(linkByDisplay[token]!);
      } else if (token.startsWith('@')) {
        onTap = () => widget.onMention(token.substring(1));
      } else if (token.startsWith('#')) {
        onTap = () => widget.onHashtag(token);
      } else {
        onTap = () => widget.onLink(token);
      }
      spans.add(
        TextSpan(text: token, style: linkStyle, recognizer: _recognizer(onTap)),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(children: _spans(theme.colorScheme.primary)),
      style: widget.style ?? theme.textTheme.bodyLarge,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

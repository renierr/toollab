import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class MarkdownSpanBuilder {
  final Color accentColor;

  MarkdownSpanBuilder({this.accentColor = AppTheme.accentTeal});

  TextSpan buildTextSpan({
    required BuildContext context,
    required String text,
    TextStyle? style,
  }) {
    final theme = Theme.of(context);
    final baseTextStyle =
        style ?? theme.textTheme.bodyMedium ?? const TextStyle();

    final lines = text.split('\n');
    final spans = <TextSpan>[];
    bool inCodeBlock = false;
    bool firstRefSeen = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;

      // Extract trailing spaces to prevent cursor layout issues on styled spans
      final trailingMatch = RegExp(r'([ \t]+)$').firstMatch(line);
      final String trailingSpaces;
      final String styledPart;
      if (trailingMatch != null) {
        trailingSpaces = trailingMatch.group(1)!;
        styledPart = line.substring(0, line.length - trailingSpaces.length);
      } else {
        trailingSpaces = '';
        styledPart = line;
      }

      TextSpan? lineSpan;

      if (styledPart.trimLeft().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        lineSpan = _styleCodeBlockLine(styledPart, baseTextStyle, theme);
      } else if (inCodeBlock) {
        lineSpan = _styleCodeLine(styledPart, baseTextStyle, theme);
      } else {
        final refDefMatch = RegExp(
          r'^(\[[^\]]+\]:\s*)(data:image/[^;]+;base64,)(.*)$',
        ).firstMatch(styledPart);
        if (refDefMatch != null) {
          final prefix = refDefMatch.group(1)!;
          final mime = refDefMatch.group(2)!;
          final base64Data = refDefMatch.group(3)!;
          final previewData = base64Data.length > 30
              ? '${base64Data.substring(0, 30)}...'
              : base64Data;

          final isFirst = !firstRefSeen;
          if (isFirst) firstRefSeen = true;

          final refBgColor = theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.15,
          );
          final lineStyle = baseTextStyle.copyWith(
            backgroundColor: refBgColor,
            decoration: isFirst ? TextDecoration.overline : null,
            decorationColor: isFirst ? theme.colorScheme.outlineVariant : null,
            decorationThickness: isFirst ? 2.0 : null,
          );

          lineSpan = TextSpan(
            style: lineStyle,
            children: [
              TextSpan(
                text: prefix,
                style: lineStyle.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: mime,
                style: lineStyle.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              TextSpan(
                text: previewData,
                style: lineStyle.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ],
          );
        }

        final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(styledPart);
        if (headerMatch != null) {
          final level = headerMatch.group(1)!.length;
          final content = headerMatch.group(2)!;
          lineSpan = _buildHeaderLine(
            styledPart,
            headerMatch.group(1)!,
            content,
            level,
            baseTextStyle,
            theme,
          );
        }

        if (styledPart.startsWith('> ')) {
          final content = styledPart.substring(2);
          lineSpan = _buildBlockquoteLine(styledPart, content, baseTextStyle, theme);
        }

        final bulletMatch = RegExp(
          r'^(\s*)([-*+]\s+\[([ xX])\]\s+|[-*+]\s+)(.*)$',
        ).firstMatch(styledPart);
        if (bulletMatch != null) {
          final prefix = bulletMatch.group(1) ?? '';
          final marker = bulletMatch.group(2) ?? '';
          final checkboxVal = bulletMatch.group(3);
          final content = bulletMatch.group(4) ?? '';
          lineSpan = _buildListLine(
            styledPart,
            prefix,
            marker,
            checkboxVal,
            content,
            baseTextStyle,
            theme,
          );
        }

        final orderedMatch = RegExp(r'^(\s*)(\d+\.\s+)(.*)$').firstMatch(styledPart);
        if (orderedMatch != null) {
          final prefix = orderedMatch.group(1) ?? '';
          final marker = orderedMatch.group(2) ?? '';
          final content = orderedMatch.group(3) ?? '';
          lineSpan = _buildListLine(
            styledPart,
            prefix,
            marker,
            null,
            content,
            baseTextStyle,
            theme,
          );
        }

        lineSpan ??= TextSpan(
          children: _parseInlineStyles(styledPart, baseTextStyle, theme),
        );
      }

      final finalSpan = trailingSpaces.isNotEmpty
          ? TextSpan(
              children: [
                lineSpan,
                TextSpan(text: trailingSpaces, style: baseTextStyle),
              ],
            )
          : lineSpan;

      spans.add(finalSpan);
      if (!isLastLine) {
        spans.add(TextSpan(text: '\n', style: baseTextStyle));
      }
    }

    return TextSpan(children: spans);
  }

  TextSpan _styleCodeBlockLine(
    String line,
    TextStyle baseStyle,
    ThemeData theme,
  ) {
    final fadedColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    return TextSpan(
      text: line,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: fadedColor,
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
      ),
    );
  }

  TextSpan _styleCodeLine(String line, TextStyle baseStyle, ThemeData theme) {
    return TextSpan(
      text: line,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
      ),
    );
  }

  TextSpan _buildHeaderLine(
    String fullLine,
    String hashPrefix,
    String content,
    int level,
    TextStyle baseStyle,
    ThemeData theme,
  ) {
    final fadedColor = theme.colorScheme.onSurface.withValues(alpha: 0.25);

    TextStyle headerStyle;
    switch (level) {
      case 1:
        headerStyle =
            theme.textTheme.headlineMedium?.copyWith(color: accentColor) ??
            baseStyle;
        break;
      case 2:
        headerStyle = theme.textTheme.headlineSmall ?? baseStyle;
        break;
      case 3:
        headerStyle = theme.textTheme.titleLarge ?? baseStyle;
        break;
      case 4:
        headerStyle = theme.textTheme.titleMedium ?? baseStyle;
        break;
      case 5:
        headerStyle = theme.textTheme.titleSmall ?? baseStyle;
        break;
      case 6:
      default:
        headerStyle = theme.textTheme.bodyLarge ?? baseStyle;
        break;
    }

    headerStyle = baseStyle
        .merge(headerStyle)
        .copyWith(fontWeight: FontWeight.bold, height: 1.2);

    return TextSpan(
      children: [
        TextSpan(
          text: '$hashPrefix ',
          style: headerStyle.copyWith(color: fadedColor),
        ),
        ..._parseInlineStyles(content, headerStyle, theme),
      ],
    );
  }

  TextSpan _buildBlockquoteLine(
    String fullLine,
    String content,
    TextStyle baseStyle,
    ThemeData theme,
  ) {
    final blockquoteStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return TextSpan(
      children: [
        TextSpan(
          text: '> ',
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
        ),
        ..._parseInlineStyles(content, blockquoteStyle, theme),
      ],
    );
  }

  TextSpan _buildListLine(
    String fullLine,
    String indent,
    String marker,
    String? checkboxVal,
    String content,
    TextStyle baseStyle,
    ThemeData theme,
  ) {
    final markerStyle = TextStyle(
      color: accentColor,
      fontWeight: FontWeight.bold,
    );

    final List<TextSpan> children = [];
    if (indent.isNotEmpty) {
      children.add(TextSpan(text: indent, style: baseStyle));
    }

    if (checkboxVal != null) {
      final isChecked = checkboxVal.toLowerCase() == 'x';
      final bracketColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);
      final checkColor = isChecked
          ? AppTheme.statusGreen
          : theme.colorScheme.onSurface.withValues(alpha: 0.35);

      final bulletChar = marker[0];
      children.add(TextSpan(text: '$bulletChar ', style: markerStyle));
      children.add(
        TextSpan(
          text: '[',
          style: TextStyle(color: bracketColor),
        ),
      );
      children.add(
        TextSpan(
          text: isChecked ? 'x' : ' ',
          style: TextStyle(color: checkColor, fontWeight: FontWeight.bold),
        ),
      );
      children.add(
        TextSpan(
          text: '] ',
          style: TextStyle(color: bracketColor),
        ),
      );
    } else {
      children.add(TextSpan(text: marker, style: markerStyle));
    }

    children.addAll(_parseInlineStyles(content, baseStyle, theme));
    return TextSpan(children: children);
  }

  List<TextSpan> _parseInlineStyles(
    String lineText,
    TextStyle baseStyle,
    ThemeData theme,
  ) {
    if (lineText.isEmpty) return [];

    final fadedColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: (baseStyle.fontSize ?? 14) * 0.9,
      color: theme.colorScheme.onSurface,
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.22),
    );

    List<_Segment> segments = [_Segment(lineText, baseStyle, isLocked: false)];

    segments = _applyRegexRule(segments, RegExp(r'`([^`\n]+)`'), (match) {
      final content = match.group(1)!;
      return [
        _Segment('`', codeStyle.copyWith(color: fadedColor), isLocked: true),
        _Segment(content, codeStyle, isLocked: true),
        _Segment('`', codeStyle.copyWith(color: fadedColor), isLocked: true),
      ];
    });

    segments = _applyRegexRule(
      segments,
      RegExp(r'\[([^\]\n]+)\]\(([^)\n]+)\)'),
      (match) {
        final linkText = match.group(1)!;
        final url = match.group(2)!;

        final linkTextStyle = baseStyle.copyWith(
          color: accentColor,
          decoration: TextDecoration.underline,
          decorationColor: accentColor,
        );
        final linkMarkerStyle = TextStyle(color: fadedColor);

        return [
          _Segment('[', linkMarkerStyle, isLocked: true),
          _Segment(linkText, linkTextStyle, isLocked: false),
          _Segment('](', linkMarkerStyle, isLocked: true),
          _Segment(url, linkMarkerStyle, isLocked: true),
          _Segment(')', linkMarkerStyle, isLocked: true),
        ];
      },
    );

    segments = _applyRegexRule(
      segments,
      RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__'),
      (match) {
        final content = match.group(1) ?? match.group(2) ?? '';
        final marker = match.group(0)!.substring(0, 2);

        return [
          _Segment(marker, TextStyle(color: fadedColor), isLocked: true),
          _Segment(
            content,
            const TextStyle(fontWeight: FontWeight.bold),
            isLocked: false,
          ),
          _Segment(marker, TextStyle(color: fadedColor), isLocked: true),
        ];
      },
    );

    segments = _applyRegexRule(segments, RegExp(r'\*([^*]+)\*|_([^_]+)_'), (
      match,
    ) {
      final content = match.group(1) ?? match.group(2) ?? '';
      final marker = match.group(0)!.substring(0, 1);

      return [
        _Segment(marker, TextStyle(color: fadedColor), isLocked: true),
        _Segment(
          content,
          const TextStyle(fontStyle: FontStyle.italic),
          isLocked: false,
        ),
        _Segment(marker, TextStyle(color: fadedColor), isLocked: true),
      ];
    });

    segments = _applyRegexRule(segments, RegExp(r'~~([^~]+)~~'), (match) {
      final content = match.group(1)!;
      return [
        _Segment('~~', TextStyle(color: fadedColor), isLocked: true),
        _Segment(
          content,
          const TextStyle(decoration: TextDecoration.lineThrough),
          isLocked: false,
        ),
        _Segment('~~', TextStyle(color: fadedColor), isLocked: true),
      ];
    });

    return segments.map((seg) {
      return TextSpan(text: seg.text, style: seg.style);
    }).toList();
  }

  List<_Segment> _applyRegexRule(
    List<_Segment> segments,
    RegExp regex,
    List<_Segment> Function(Match match) replaceBuilder,
  ) {
    final List<_Segment> result = [];

    for (final seg in segments) {
      if (seg.isLocked || seg.text.isEmpty) {
        result.add(seg);
        continue;
      }

      final matches = regex.allMatches(seg.text);
      if (matches.isEmpty) {
        result.add(seg);
        continue;
      }

      int lastIndex = 0;
      for (final match in matches) {
        if (match.start > lastIndex) {
          result.add(
            _Segment(
              seg.text.substring(lastIndex, match.start),
              seg.style,
              isLocked: false,
            ),
          );
        }

        final replacement = replaceBuilder(match);
        for (final repSeg in replacement) {
          final mergedStyle = seg.style.merge(repSeg.style);
          result.add(
            _Segment(repSeg.text, mergedStyle, isLocked: repSeg.isLocked),
          );
        }

        lastIndex = match.end;
      }

      if (lastIndex < seg.text.length) {
        result.add(
          _Segment(seg.text.substring(lastIndex), seg.style, isLocked: false),
        );
      }
    }

    return result;
  }
}

class _Segment {
  final String text;
  final TextStyle style;
  final bool isLocked;

  _Segment(this.text, this.style, {this.isLocked = false});
}

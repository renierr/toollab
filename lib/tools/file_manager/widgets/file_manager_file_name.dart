import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shortens a name in the middle so its start and its extension stay visible.
class FileManagerFileName extends StatelessWidget {
  static const String _ellipsis = '…';
  static const int _maxExtensionLength = 10;

  final String name;
  final TextStyle? style;
  final int maxLines;

  const FileManagerFileName({
    super.key,
    required this.name,
    this.style,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    // Measure with the exact style, scaler and direction Text renders with.
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        bool fits(String value) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: effectiveStyle),
            maxLines: maxLines,
            textDirection: textDirection,
            textScaler: textScaler,
          )..layout(maxWidth: constraints.maxWidth);
          final exceeded = painter.didExceedMaxLines;
          painter.dispose();
          return !exceeded;
        }

        return Text(
          _shorten(name, fits),
          style: effectiveStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  String _shorten(String value, bool Function(String) fits) {
    if (fits(value)) return value;

    final chars = value.characters.toList();
    final dotIndex = value.lastIndexOf('.');
    final extensionLength = dotIndex > 0
        ? value.substring(dotIndex).characters.length
        : 0;
    final minTail = extensionLength > _maxExtensionLength
        ? 4
        : extensionLength + 4;

    String candidate(int keep) {
      final tail = math.min(keep, math.max(keep ~/ 3, minTail));
      final head = keep - tail;
      return '${chars.take(head).join()}$_ellipsis'
          '${chars.skip(chars.length - tail).join()}';
    }

    var low = 0;
    var high = chars.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (fits(candidate(middle))) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return candidate(low);
  }
}

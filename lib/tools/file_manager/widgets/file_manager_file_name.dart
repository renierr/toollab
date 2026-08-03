import 'package:flutter/material.dart';

class FileManagerFileName extends StatelessWidget {
  final String name;

  const FileManagerFileName({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayName = _truncate(name, style, constraints.maxWidth);
        return Text(displayName, style: style, maxLines: 2);
      },
    );
  }

  String _truncate(String value, TextStyle style, double maxWidth) {
    if (_fits(value, style, maxWidth)) return value;

    final dotIndex = value.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == value.length - 1) return value;

    final base = value.substring(0, dotIndex).runes.toList();
    final extension = value.substring(dotIndex);
    var low = 0;
    var high = base.length;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      final candidate =
          '${String.fromCharCodes(base.take(middle))}...$extension';
      if (_fits(candidate, style, maxWidth)) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return '${String.fromCharCodes(base.take(low))}...$extension';
  }

  bool _fits(String value, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }
}

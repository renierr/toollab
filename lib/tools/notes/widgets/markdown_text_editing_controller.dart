import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/notes/widgets/markdown_span_builder.dart';

class MarkdownTextEditingController extends TextEditingController {
  bool showRawSource;
  final Color accentColor;
  late final MarkdownSpanBuilder _spanBuilder;
  bool _rewriting = false;

  static final _listPrefix = RegExp(
    r'^(\s*)([-*+]\s\[[ x]\]\s|[-*+]\s|\d+[.)]\s)',
  );

  MarkdownTextEditingController({
    super.text,
    this.showRawSource = false,
    this.accentColor = AppTheme.accentTeal,
  }) {
    _spanBuilder = MarkdownSpanBuilder(accentColor: accentColor);
  }

  // List continuation runs off the incoming value, not a key event: Android's
  // soft Enter is inserted by the engine and never reaches the key handler.
  @override
  set value(TextEditingValue newValue) {
    if (_rewriting) {
      super.value = newValue;
      return;
    }
    _rewriting = true;
    super.value = _continueList(value, newValue) ?? newValue;
    _rewriting = false;
  }

  TextEditingValue? _continueList(TextEditingValue old, TextEditingValue next) {
    final selection = next.selection;
    if (!selection.isCollapsed) return null;

    final cursor = selection.baseOffset;
    final text = next.text;
    if (cursor < 2 || text.length != old.text.length + 1) return null;
    if (text[cursor - 1] != '\n') return null;
    if (text.substring(0, cursor - 1) + text.substring(cursor) != old.text) {
      return null;
    }

    final newlinePos = cursor - 1;
    final lineStart = text.lastIndexOf('\n', newlinePos - 1) + 1;
    final match = _listPrefix.firstMatch(text.substring(lineStart, newlinePos));
    if (match == null) return null;

    final prefix = match.group(0)!;
    final rest = text.substring(lineStart + prefix.length, newlinePos);
    final after = text.substring(cursor);

    if (rest.trim().isEmpty) {
      final before = text.substring(0, lineStart);
      return TextEditingValue(
        text: '$before\n$after',
        selection: TextSelection.collapsed(offset: before.length + 1),
      );
    }

    return TextEditingValue(
      text: '${text.substring(0, cursor)}$prefix$after',
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (showRawSource) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    return _spanBuilder.buildTextSpan(
      context: context,
      text: text,
      style: style,
    );
  }
}

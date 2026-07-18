import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/notes/widgets/markdown_span_builder.dart';

class MarkdownTextEditingController extends TextEditingController {
  final BuildContext context;
  bool showRawSource;
  final Color accentColor;
  bool isProgrammaticUpdate = false;
  late final MarkdownSpanBuilder _spanBuilder;

  MarkdownTextEditingController({
    required this.context,
    super.text,
    this.showRawSource = false,
    this.accentColor = AppTheme.accentTeal,
  }) {
    _spanBuilder = MarkdownSpanBuilder(accentColor: accentColor);
  }

  int _findRefSectionStart(String txt) {
    final match = RegExp(r'\[img_ref_\d+\]: data:image/').firstMatch(txt);
    return match?.start ?? -1;
  }

  void _showReadOnlyWarning() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notesAttachmentReadOnly),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (isProgrammaticUpdate || showRawSource) {
      super.value = newValue;
      return;
    }

    final oldText = text;
    final oldRefStart = _findRefSectionStart(oldText);

    if (oldRefStart == -1) {
      super.value = newValue;
      return;
    }

    final oldRefText = oldText.substring(oldRefStart);
    final newText = newValue.text;

    if (!newText.endsWith(oldRefText)) {
      if (newText.isEmpty) {
        super.value = newValue;
        return;
      }
      _showReadOnlyWarning();
      return;
    }

    final newRefStart = newText.length - oldRefText.length;
    if (newRefStart > 0 && newText[newRefStart - 1] != '\n') {
      _showReadOnlyWarning();
      return;
    }

    super.value = newValue;
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

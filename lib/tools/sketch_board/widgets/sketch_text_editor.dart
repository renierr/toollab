import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Multi-line text-entry dialog for placing/editing a text element.
Future<String?> showSketchTextDialog(BuildContext context, String initial) {
  final l10n = AppLocalizations.of(context);
  return _showInput(
    context,
    title: l10n.sketchTextTitle,
    hint: l10n.sketchTextHint,
    initial: initial,
    multiline: true,
  );
}

/// Single-line dialog for naming a saved drawing.
Future<String?> showSketchNameDialog(BuildContext context, String initial) {
  final l10n = AppLocalizations.of(context);
  return _showInput(
    context,
    title: l10n.sketchSaveTitle,
    hint: l10n.sketchSaveHint,
    initial: initial,
    multiline: false,
  );
}

Future<String?> _showInput(
  BuildContext context, {
  required String title,
  required String hint,
  required String initial,
  required bool multiline,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      hint: hint,
      initial: initial,
      multiline: multiline,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;
  final bool multiline;

  const _InputDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.multiline,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.multiline ? null : 1,
        textInputAction: widget.multiline
            ? TextInputAction.newline
            : TextInputAction.done,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: widget.multiline
            ? null
            : (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

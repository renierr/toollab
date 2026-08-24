import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileNameDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const FileNameDialog({
    super.key,
    required this.title,
    required this.initialValue,
  });

  @override
  State<FileNameDialog> createState() => _FileNameDialogState();
}

class _FileNameDialogState extends State<FileNameDialog> {
  late final TextEditingController _controller =
      TextEditingController.fromValue(
        TextEditingValue(
          text: widget.initialValue,
          // Caret before the extension, so renaming extends the name instead of
          // the suffix.
          selection: TextSelection.collapsed(offset: _nameEnd),
        ),
      );

  /// Offset of the extension dot, or the end of the text when there is none. A
  /// leading dot is part of the name (dotfiles), not an extension.
  int get _nameEnd {
    final dot = widget.initialValue.lastIndexOf('.');
    return dot > 0 ? dot : widget.initialValue.length;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerNameDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const FileManagerNameDialog({
    super.key,
    required this.title,
    required this.initialValue,
  });

  @override
  State<FileManagerNameDialog> createState() => _FileManagerNameDialogState();
}

class _FileManagerNameDialogState extends State<FileManagerNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

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
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

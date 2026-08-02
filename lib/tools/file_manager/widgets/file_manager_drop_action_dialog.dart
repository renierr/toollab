import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerDropActionDialog extends StatelessWidget {
  const FileManagerDropActionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerDropActionTitle),
      content: Text(l10n.fileManagerDropActionMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.fileManagerMove),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCopy),
        ),
      ],
    );
  }
}

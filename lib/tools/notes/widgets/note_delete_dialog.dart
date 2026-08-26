import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

enum NoteDeleteChoice { cascade, keepFollowUps }

/// Delete confirmation that offers to keep or remove the follow-ups.
class NoteDeleteDialog {
  static Future<NoteDeleteChoice?> show({
    required BuildContext context,
    required int followUpCount,
  }) {
    final l10n = AppLocalizations.of(context);
    return showDialog<NoteDeleteChoice>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.notesDeleteNoteTitle),
        content: Text(l10n.notesDeleteWithFollowUpsMessage(followUpCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(NoteDeleteChoice.keepFollowUps),
            child: Text(l10n.notesDeleteKeepFollowUps),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(NoteDeleteChoice.cascade),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.notesDeleteWithFollowUps),
          ),
        ],
      ),
    );
  }
}

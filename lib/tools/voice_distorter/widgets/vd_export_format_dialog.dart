import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/responsive_alert_dialog.dart';
import '../engine/clip_export_format.dart';

String _describe(AppLocalizations l10n, ClipExportFormat format) =>
    switch (format) {
      ClipExportFormat.wav => l10n.voiceDistorterFormatUncompressed,
      ClipExportFormat.ogg ||
      ClipExportFormat.opus => l10n.voiceDistorterFormatCompressed,
      ClipExportFormat.flac => l10n.voiceDistorterFormatLossless,
    };

Future<ClipExportFormat?> showExportFormatDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<ClipExportFormat>(
    context: context,
    builder: (dialogContext) => ResponsiveAlertDialog(
      title: Text(l10n.voiceDistorterExportFormatTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final format in ClipExportFormat.values)
            ListTile(
              title: Text(format.label),
              subtitle: Text(_describe(l10n, format)),
              trailing: Text('.${format.extension}'),
              onTap: () => Navigator.of(dialogContext).pop(format),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

enum TreadmillLeaveChoice { stay, background, stopAndSave }

/// Guards the way out of the tool while a workout is recording.
class TreadmillActiveSessionDialog extends StatelessWidget {
  const TreadmillActiveSessionDialog._();

  static Future<TreadmillLeaveChoice?> show(BuildContext context) =>
      showDialog<TreadmillLeaveChoice>(
        context: context,
        builder: (_) => const TreadmillActiveSessionDialog._(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.directions_run_rounded),
      title: Text(l10n.treadmillSessionRunningTitle),
      content: Text(l10n.treadmillSessionRunningMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(TreadmillLeaveChoice.stay),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(TreadmillLeaveChoice.background),
          child: Text(l10n.treadmillKeepRecording),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(TreadmillLeaveChoice.stopAndSave),
          child: Text(l10n.treadmillStopAndSave),
        ),
      ],
    );
  }
}

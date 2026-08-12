import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../treadmill_session.dart';
import '../workout_details_stats.dart';

enum TreadmillRecoveryChoice { resume, save, discard }

/// Offered when the app comes back with a workout that was still recording.
class TreadmillRecoveredSessionDialog extends StatelessWidget {
  final TreadmillSession session;

  const TreadmillRecoveredSessionDialog._({required this.session});

  static Future<TreadmillRecoveryChoice?> show(
    BuildContext context,
    TreadmillSession session,
  ) => showDialog<TreadmillRecoveryChoice>(
    context: context,
    builder: (_) => TreadmillRecoveredSessionDialog._(session: session),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.restore_rounded),
      title: Text(l10n.treadmillRecoveredTitle),
      content: Text(
        l10n.treadmillRecoveredMessage(
          formatWorkoutDuration(session.elapsedTime),
          session.distance.toStringAsFixed(2),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(TreadmillRecoveryChoice.discard),
          child: Text(l10n.treadmillRecoveredDiscard),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(TreadmillRecoveryChoice.save),
          child: Text(l10n.treadmillRecoveredSave),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(TreadmillRecoveryChoice.resume),
          child: Text(l10n.treadmillRecoveredResume),
        ),
      ],
    );
  }
}

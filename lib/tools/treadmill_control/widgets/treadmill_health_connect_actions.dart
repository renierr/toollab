import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/health_connect_actions.dart';

import '../treadmill_control_state.dart';
import '../treadmill_health_connect_publisher.dart' show TreadmillPublishResult;
import '../treadmill_publish_message.dart';

/// Manual Health Connect actions for treadmill workouts.
class TreadmillHealthConnectActions extends StatelessWidget {
  const TreadmillHealthConnectActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HealthConnectActions<TreadmillPublishResult>(
      publishTitle: l10n.treadmillPublishNow,
      publishSubtitle: l10n.treadmillPublishNowSubtitle,
      removeTitle: l10n.treadmillRemoveFromHealthConnect,
      removeSubtitle: l10n.treadmillRemoveFromHealthConnectSubtitle,
      removeConfirmMessage: l10n.treadmillRemoveFromHealthConnectConfirm,
      removeConfirmActionLabel: l10n.treadmillRemoveFromHealthConnectAction,
      cancelLabel: l10n.commonCancel,
      onPublish: () =>
          context.read<TreadmillControlState>().publishToHealthConnect(),
      onRemove: () =>
          context.read<TreadmillControlState>().removeFromHealthConnect(),
      publishResultMessage: (l10n, result) =>
          treadmillPublishMessage(l10n, result!),
      removeResultMessage: (l10n, result) {
        final r = result!;
        return r.failed > 0
            ? l10n.treadmillRemoveFromHealthConnectFailed
            : l10n.treadmillRemoveFromHealthConnectDone(r.published);
      },
    );
  }
}

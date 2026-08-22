import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/health_connect_actions.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_health_connect_publisher.dart' show RenphoPublishResult;
import '../renpho_publish_message.dart';

/// Manual Health Connect actions for renpho measurements.
class RenphoHealthConnectActions extends StatelessWidget {
  const RenphoHealthConnectActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HealthConnectActions<RenphoPublishResult>(
      publishTitle: l10n.renphoPublishNow,
      publishSubtitle: l10n.renphoPublishNowSubtitle,
      removeTitle: l10n.renphoRemoveFromHealthConnect,
      removeSubtitle: l10n.renphoRemoveFromHealthConnectSubtitle,
      removeConfirmMessage: l10n.renphoRemoveFromHealthConnectConfirm,
      removeConfirmActionLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
      onPublish: () =>
          context.read<RenphoBleProbeState>().publishToHealthConnect(),
      onRemove: () =>
          context.read<RenphoBleProbeState>().removeFromHealthConnect(),
      publishResultMessage: (l10n, result) =>
          renphoPublishMessage(l10n, result!),
      removeResultMessage: (l10n, result) {
        final r = result!;
        return r.failed > 0
            ? l10n.renphoRemoveFromHealthConnectFailed
            : l10n.renphoRemoveFromHealthConnectDone(r.published);
      },
    );
  }
}

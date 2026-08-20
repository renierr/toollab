import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_publish_message.dart';

/// Manual Health Connect actions: push what is pending, or wipe everything this
/// app wrote so the next push recreates it.
class RenphoHealthConnectActions extends StatefulWidget {
  const RenphoHealthConnectActions({super.key});

  @override
  State<RenphoHealthConnectActions> createState() =>
      _RenphoHealthConnectActionsState();
}

class _RenphoHealthConnectActionsState
    extends State<RenphoHealthConnectActions> {
  bool _publishing = false;
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _publishing || _removing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: Text(l10n.renphoPublishNow),
          subtitle: Text(l10n.renphoPublishNowSubtitle),
          trailing: _publishing ? const _TileSpinner() : null,
          onTap: busy ? null : _publish,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: AppTheme.statusRed,
          ),
          title: Text(l10n.renphoRemoveFromHealthConnect),
          subtitle: Text(l10n.renphoRemoveFromHealthConnectSubtitle),
          trailing: _removing ? const _TileSpinner() : null,
          onTap: busy ? null : _remove,
        ),
      ],
    );
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<RenphoBleProbeState>();
    setState(() => _publishing = true);
    try {
      final result = await state.publishToHealthConnect();
      messenger.showSnackBar(
        SnackBar(content: Text(renphoPublishMessage(l10n, result))),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<RenphoBleProbeState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.renphoRemoveFromHealthConnect,
      message: l10n.renphoRemoveFromHealthConnectConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      final result = await state.removeFromHealthConnect();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.failed > 0
                ? l10n.renphoRemoveFromHealthConnectFailed
                : l10n.renphoRemoveFromHealthConnectDone(result.published),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }
}

class _TileSpinner extends StatelessWidget {
  const _TileSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

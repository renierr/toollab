import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

import '../treadmill_control_state.dart';
import '../treadmill_publish_message.dart';

/// Manual Health Connect actions: push what is pending, or wipe everything this
/// app wrote so the next push recreates it.
class TreadmillHealthConnectActions extends StatefulWidget {
  const TreadmillHealthConnectActions({super.key});

  @override
  State<TreadmillHealthConnectActions> createState() =>
      _TreadmillHealthConnectActionsState();
}

class _TreadmillHealthConnectActionsState
    extends State<TreadmillHealthConnectActions> {
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
          title: Text(l10n.treadmillPublishNow),
          subtitle: Text(l10n.treadmillPublishNowSubtitle),
          trailing: _publishing ? const _TileSpinner() : null,
          onTap: busy ? null : _publish,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: AppTheme.statusRed,
          ),
          title: Text(l10n.treadmillRemoveFromHealthConnect),
          subtitle: Text(l10n.treadmillRemoveFromHealthConnectSubtitle),
          trailing: _removing ? const _TileSpinner() : null,
          onTap: busy ? null : _remove,
        ),
      ],
    );
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<TreadmillControlState>();
    setState(() => _publishing = true);
    try {
      final result = await state.publishToHealthConnect();
      messenger.showSnackBar(
        SnackBar(content: Text(treadmillPublishMessage(l10n, result))),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<TreadmillControlState>();
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.treadmillRemoveFromHealthConnect,
      message: l10n.treadmillRemoveFromHealthConnectConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.treadmillRemoveFromHealthConnectAction,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      final result = await state.removeFromHealthConnect();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.failed > 0
                ? l10n.treadmillRemoveFromHealthConnectFailed
                : l10n.treadmillRemoveFromHealthConnectDone(result.published),
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

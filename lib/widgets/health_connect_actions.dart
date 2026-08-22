import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

/// Small trailing spinner for list tiles while an async action runs.
class BusyTileSpinner extends StatelessWidget {
  const BusyTileSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// Manual Health Connect actions: push what is pending, or wipe everything
/// this app wrote so the next push recreates it.
///
/// Labels are resolved by the caller so each tool can use its own l10n keys;
/// [onPublish] / [onRemove] return tool-specific results that are fed back
/// through the message builders for the snackbars.
class HealthConnectActions<T> extends StatefulWidget {
  const HealthConnectActions({
    super.key,
    required this.publishTitle,
    required this.publishSubtitle,
    required this.removeTitle,
    required this.removeSubtitle,
    required this.removeConfirmMessage,
    required this.removeConfirmActionLabel,
    required this.cancelLabel,
    required this.onPublish,
    required this.onRemove,
    required this.publishResultMessage,
    required this.removeResultMessage,
  });

  final String publishTitle;
  final String publishSubtitle;
  final String removeTitle;
  final String removeSubtitle;
  final String removeConfirmMessage;
  final String removeConfirmActionLabel;
  final String cancelLabel;

  final Future<T?> Function() onPublish;
  final Future<T?> Function() onRemove;
  final String Function(AppLocalizations l10n, T? result) publishResultMessage;
  final String Function(AppLocalizations l10n, T? result) removeResultMessage;

  @override
  State<HealthConnectActions<T>> createState() =>
      _HealthConnectActionsState<T>();
}

class _HealthConnectActionsState<T> extends State<HealthConnectActions<T>> {
  bool _publishing = false;
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final busy = _publishing || _removing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: Text(widget.publishTitle),
          subtitle: Text(widget.publishSubtitle),
          trailing: _publishing ? const BusyTileSpinner() : null,
          onTap: busy ? null : _publish,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: AppTheme.statusRed,
          ),
          title: Text(widget.removeTitle),
          subtitle: Text(widget.removeSubtitle),
          trailing: _removing ? const BusyTileSpinner() : null,
          onTap: busy ? null : _remove,
        ),
      ],
    );
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    try {
      final result = await widget.onPublish();
      messenger.showSnackBar(
        SnackBar(content: Text(widget.publishResultMessage(l10n, result))),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: widget.removeTitle,
      message: widget.removeConfirmMessage,
      cancelLabel: widget.cancelLabel,
      confirmLabel: widget.removeConfirmActionLabel,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      final result = await widget.onRemove();
      messenger.showSnackBar(
        SnackBar(content: Text(widget.removeResultMessage(l10n, result))),
      );
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }
}

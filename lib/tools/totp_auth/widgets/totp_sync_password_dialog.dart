import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class TotpSyncPasswordResult {
  /// `null` removes the password.
  final String? password;

  const TotpSyncPasswordResult(this.password);
}

class TotpSyncPasswordDialog extends StatefulWidget {
  final String? current;

  const TotpSyncPasswordDialog({super.key, this.current});

  static Future<TotpSyncPasswordResult?> show(
    BuildContext context, {
    String? current,
  }) {
    return showDialog<TotpSyncPasswordResult>(
      context: context,
      builder: (_) => TotpSyncPasswordDialog(current: current),
    );
  }

  @override
  State<TotpSyncPasswordDialog> createState() => _TotpSyncPasswordDialogState();
}

class _TotpSyncPasswordDialogState extends State<TotpSyncPasswordDialog> {
  late final TextEditingController _controller;
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text;
    Navigator.of(
      context,
    ).pop(TotpSyncPasswordResult(value.isEmpty ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPassword = widget.current != null && widget.current!.isNotEmpty;
    final tooShort = _controller.text.isNotEmpty && _controller.text.length < 8;

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.totpSyncPassword),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.totpSyncPasswordDescription),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _hide,
              autocorrect: false,
              enableSuggestions: false,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.totpSyncPassword,
                errorText: tooShort ? l10n.totpPasswordTooShort : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hide
                      ? l10n.totpShowPassword
                      : l10n.totpHidePassword,
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(
                    _hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (hasPassword)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const TotpSyncPasswordResult(null)),
            child: Text(l10n.totpRemoveSyncPassword),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: tooShort ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

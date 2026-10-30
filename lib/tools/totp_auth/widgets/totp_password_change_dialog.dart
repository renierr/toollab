import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/sync_error_message.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/widgets/password_visibility_button.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class TotpPasswordChangeDialog extends StatefulWidget {
  const TotpPasswordChangeDialog({
    super.key,
    required this.adopt,
    required this.submit,
  });

  final bool adopt;
  final Future<void> Function(String current, String password) submit;

  static Future<bool?> show(
    BuildContext context, {
    required bool adopt,
    required Future<void> Function(String current, String password) submit,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TotpPasswordChangeDialog(adopt: adopt, submit: submit),
  );

  @override
  State<TotpPasswordChangeDialog> createState() =>
      _TotpPasswordChangeDialogState();
}

class _TotpPasswordChangeDialogState extends State<TotpPasswordChangeDialog> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    if (_password.text.length < 8) {
      setState(() => _error = l10n.toolLockPasswordTooShort);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = l10n.toolLockPasswordMismatch);
      return;
    }
    if (!widget.adopt && _current.text == _password.text) {
      setState(() => _error = l10n.totpPasswordSame);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_current.text, _password.text);
      if (mounted) Navigator.pop(context, true);
    } on SecretBoxAuthenticationError {
      if (mounted) setState(() => _error = l10n.totpPasswordWrongCurrent);
    } on SyncPasswordMismatchException catch (e) {
      if (mounted) setState(() => _error = syncErrorMessage(e, l10n));
    } on SyncFailures catch (e) {
      if (mounted) setState(() => _error = syncErrorMessage(e, l10n));
    } catch (e) {
      if (mounted) setState(() => _error = l10n.toolLockError(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(
        widget.adopt ? l10n.totpAdoptPasswordTitle : l10n.totpChangePassword,
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.adopt
                  ? l10n.totpAdoptPasswordDescription
                  : l10n.totpChangePasswordDescription,
            ),
            if (!widget.adopt)
              TextField(
                controller: _current,
                obscureText: _hideCurrent,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.totpCurrentPassword,
                  suffixIcon: PasswordVisibilityButton(
                    hidden: _hideCurrent,
                    onPressed: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                  ),
                ),
              ),
            TextField(
              controller: _password,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.totpNewPassword,
                suffixIcon: PasswordVisibilityButton(
                  hidden: _hidePassword,
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            TextField(
              controller: _confirm,
              obscureText: _hideConfirm,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.totpConfirmNewPassword,
                suffixIcon: PasswordVisibilityButton(
                  hidden: _hideConfirm,
                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

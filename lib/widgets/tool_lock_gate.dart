import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/tool_vault_crypto.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';

class ToolLockGate extends StatefulWidget {
  const ToolLockGate({
    super.key,
    required this.controller,
    required this.setup,
    required this.unlock,
    required this.unlockBiometric,
    required this.reset,
  });

  final ToolLockController controller;
  final Future<void> Function(String) setup;
  final Future<bool> Function(String) unlock;
  final Future<bool> Function() unlockBiometric;
  final Future<void> Function() reset;

  @override
  State<ToolLockGate> createState() => _ToolLockGateState();
}

class _ToolLockGateState extends State<ToolLockGate> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final value = _password.text;
    if (!widget.controller.configured && value.length < 8) {
      setState(() => _error = l10n.toolLockPasswordTooShort);
      return;
    }
    if (!widget.controller.configured && value != _confirm.text) {
      setState(() => _error = l10n.toolLockPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.controller.configured) {
        if (!await widget.unlock(value) && mounted) {
          setState(() => _error = l10n.toolLockWrongPassword);
        }
      } else {
        await widget.setup(value);
      }
    } on ExistingToolPasswordMismatch {
      if (mounted) setState(() => _error = l10n.toolLockExistingPassword);
    } on ToolVaultCleanupPending {
      if (mounted) setState(() => _error = l10n.toolLockCleanupPending);
    } catch (e) {
      if (mounted) setState(() => _error = l10n.toolLockError(e.toString()));
    } finally {
      if (mounted) {
        _password.clear();
        _confirm.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _biometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.unlockBiometric();
    } on ToolVaultCleanupPending {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).toolLockCleanupPending,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context).toolLockError(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.toolLockResetTitle,
      message: l10n.toolLockResetDescription,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.toolLockResetConfirm,
      confirmColor: AppTheme.statusRed,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.reset();
    } catch (e) {
      if (mounted) setState(() => _error = l10n.toolLockError(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.initialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final configured = widget.controller.configured;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    configured ? l10n.toolLockUnlock : l10n.toolLockSetup,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (!configured) ...[
                    const SizedBox(height: 12),
                    Text(l10n.toolLockSetupDescription),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l10n.toolLockPassword,
                      suffixIcon: _PasswordVisibilityButton(
                        hidden: _hidePassword,
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (!configured)
                    TextField(
                      controller: _confirm,
                      obscureText: _hideConfirmation,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.toolLockConfirmPassword,
                        suffixIcon: _PasswordVisibilityButton(
                          hidden: _hideConfirmation,
                          onPressed: () => setState(
                            () => _hideConfirmation = !_hideConfirmation,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      configured
                          ? l10n.toolLockUnlockAction
                          : l10n.toolLockCreate,
                    ),
                  ),
                  if (configured &&
                      widget.controller.biometric &&
                      widget.controller.supportsBiometric)
                    TextButton(
                      onPressed: _busy ? null : _biometric,
                      child: Text(l10n.toolLockBiometric),
                    ),
                  if (widget.controller.canReset)
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: Text(l10n.toolLockReset),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: hidden ? l10n.toolLockShowPassword : l10n.toolLockHidePassword,
      onPressed: onPressed,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}

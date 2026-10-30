import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class ToolLockSettingsDialog extends StatefulWidget {
  const ToolLockSettingsDialog({
    super.key,
    required this.controller,
    this.onChangePassword,
  });
  final ToolLockController controller;
  final VoidCallback? onChangePassword;

  static Future<void> show(
    BuildContext context,
    ToolLockController controller, {
    VoidCallback? onChangePassword,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ToolLockSettingsDialog(
      controller: controller,
      onChangePassword: onChangePassword,
    ),
  );

  @override
  State<ToolLockSettingsDialog> createState() => _ToolLockSettingsDialogState();
}

class _ToolLockSettingsDialogState extends State<ToolLockSettingsDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _change(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ResponsiveAlertDialog(
        scrollable: true,
        title: Text(l10n.toolLockSettings),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onChangePassword != null)
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(l10n.totpChangePassword),
                  onTap: _busy
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onChangePassword!();
                        },
                ),
              SwitchListTile(
                value: widget.controller.automatic,
                title: Text(l10n.toolLockAutomatic),
                subtitle: Text(l10n.toolLockAutomaticDescription),
                onChanged: _busy
                    ? null
                    : (value) =>
                          _change(() => widget.controller.setAutomatic(value)),
              ),
              if (widget.controller.supportsBiometric)
                SwitchListTile(
                  value: widget.controller.biometric,
                  title: Text(l10n.toolLockBiometricSetting),
                  onChanged: _busy
                      ? null
                      : (value) => _change(
                          () => widget.controller.setBiometric(value),
                        ),
                ),
              if (widget.controller.supportsBiometric &&
                  widget.controller.biometric) ...[
                DropdownButtonFormField<int>(
                  initialValue: widget.controller.biometricTimeoutMinutes,
                  decoration: InputDecoration(
                    labelText: l10n.toolLockBiometricTimeout,
                  ),
                  items: ToolLockController.biometricTimeouts
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text(
                            minutes == 0
                                ? l10n.toolLockBiometricEveryTime
                                : l10n.toolLockBiometricMinutes(minutes),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (minutes) {
                          if (minutes != null) {
                            _change(
                              () => widget.controller.setBiometricTimeout(
                                minutes,
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text(l10n.toolLockBiometricTimeoutDescription),
                if (widget.controller.automatic) ...[
                  const SizedBox(height: 8),
                  Text(l10n.toolLockBiometricAutomaticWarning),
                ],
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}

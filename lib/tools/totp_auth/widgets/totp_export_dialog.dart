import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../totp_backup.dart';

class TotpExportSelection {
  final TotpExportFormat format;
  final String? password;

  const TotpExportSelection({required this.format, this.password});
}

class TotpExportDialog extends StatefulWidget {
  final int accountCount;

  const TotpExportDialog({super.key, required this.accountCount});

  static Future<TotpExportSelection?> show(
    BuildContext context, {
    required int accountCount,
  }) {
    return showDialog<TotpExportSelection>(
      context: context,
      builder: (_) => TotpExportDialog(accountCount: accountCount),
    );
  }

  @override
  State<TotpExportDialog> createState() => _TotpExportDialogState();
}

class _TotpExportDialogState extends State<TotpExportDialog> {
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  TotpExportFormat _format = TotpExportFormat.encryptedBackup;
  String? _error;
  bool _hidePassword = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _export() {
    final l10n = AppLocalizations.of(context);
    if (_format == TotpExportFormat.encryptedBackup) {
      if (_passwordCtrl.text.length < 8) {
        setState(() => _error = l10n.totpPasswordTooShort);
        return;
      }
      if (_passwordCtrl.text != _confirmCtrl.text) {
        setState(() => _error = l10n.totpPasswordMismatch);
        return;
      }
    }
    Navigator.of(context).pop(
      TotpExportSelection(
        format: _format,
        password: _format == TotpExportFormat.encryptedBackup
            ? _passwordCtrl.text
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      title: Text(l10n.totpExportTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.totpExportAccountCount(widget.accountCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<TotpExportFormat>(
                groupValue: _format,
                onChanged: (value) => setState(() {
                  _format = value ?? TotpExportFormat.encryptedBackup;
                  _error = null;
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<TotpExportFormat>(
                      value: TotpExportFormat.encryptedBackup,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l10n.totpExportEncrypted),
                      subtitle: Text(
                        l10n.totpExportEncryptedDesc,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    RadioListTile<TotpExportFormat>(
                      value: TotpExportFormat.plainBackup,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l10n.totpExportPlain),
                      subtitle: Text(
                        l10n.totpExportPlainDesc,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    RadioListTile<TotpExportFormat>(
                      value: TotpExportFormat.otpAuthLinks,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l10n.totpExportLinks),
                      subtitle: Text(
                        l10n.totpExportLinksDesc,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              if (_format == TotpExportFormat.plainBackup)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        color: AppTheme.accentAmberLight,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.totpExportPlainWarning,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_format == TotpExportFormat.encryptedBackup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.totpExportPassword,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? l10n.totpShowPassword
                          : l10n.totpHidePassword,
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.totpExportPasswordConfirm,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.save_alt),
          label: Text(l10n.totpExportAction),
        ),
      ],
    );
  }
}

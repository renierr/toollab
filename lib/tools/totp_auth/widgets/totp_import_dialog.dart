import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../totp_import.dart';

class TotpImportDialog extends StatefulWidget {
  const TotpImportDialog({super.key});

  static Future<TotpImportResult?> show(BuildContext context) {
    return showDialog<TotpImportResult>(
      context: context,
      builder: (_) => const TotpImportDialog(),
    );
  }

  @override
  State<TotpImportDialog> createState() => _TotpImportDialogState();
}

class _TotpImportDialogState extends State<TotpImportDialog> {
  final TextEditingController _passwordCtrl = TextEditingController();
  String? _content;
  String? _fileName;
  String? _format;
  int? _detected;
  String? _error;
  bool _needsPassword = false;
  bool _busy = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'Authenticator backups',
      extensions: ['json', '2fas', 'totpbackup', 'txt', 'backup'],
      mimeTypes: ['application/json', 'text/plain'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null || !mounted) return;

    setState(() {
      _fileName = file.name;
      _busy = true;
      _error = null;
      _needsPassword = false;
      _detected = null;
      _format = null;
      _content = null;
      _passwordCtrl.clear();
    });

    try {
      final content = await file.readAsString();
      if (!mounted) return;
      _content = content;
      final probe = await TotpImporter.parseText(content);
      if (!mounted) return;
      setState(() {
        _format = probe.format;
        _detected = probe.accounts.length;
      });
    } on TotpImportException catch (e) {
      if (!mounted) return;
      if (e.code == TotpImportErrorCode.passwordRequired) {
        setState(() {
          _needsPassword = true;
          _format = e.format;
        });
      } else {
        setState(() => _error = _messageFor(e));
      }
    } catch (e) {
      errorLog('[TotpImportDialog] Failed to read backup: $e');
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).totpImportErrorInvalid,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final content = _content;
    if (content == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await TotpImporter.parseText(
        content,
        password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on TotpImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _busy = false;
      });
    } catch (e) {
      errorLog('[TotpImportDialog] Import failed: $e');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).totpImportErrorInvalid;
        _busy = false;
      });
    }
  }

  String _messageFor(TotpImportException e) {
    final l10n = AppLocalizations.of(context);
    switch (e.code) {
      case TotpImportErrorCode.passwordRequired:
        return l10n.totpImportErrorPasswordRequired;
      case TotpImportErrorCode.wrongPassword:
        return l10n.totpImportErrorWrongPassword;
      case TotpImportErrorCode.encryptedUnsupported:
        return l10n.totpImportErrorEncrypted(e.format ?? '');
      case TotpImportErrorCode.empty:
        return l10n.totpImportErrorEmpty;
      case TotpImportErrorCode.invalid:
        return l10n.totpImportErrorInvalid;
      case TotpImportErrorCode.unsupported:
        return l10n.totpImportErrorUnsupported;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canImport =
        _content != null &&
        (_detected != null || _needsPassword) &&
        !_busy &&
        (!_needsPassword || _passwordCtrl.text.isNotEmpty);

    return ResponsiveAlertDialog(
      title: Text(l10n.totpImportTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.totpImportHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(
                  _fileName == null
                      ? l10n.totpChooseFile
                      : l10n.totpChooseAnotherFile,
                ),
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fileName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_detected != null && !_needsPassword) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.totpImportDetected(
                            _detected ?? 0,
                            _format ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_needsPassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.totpImportPassword,
                    helperText: l10n.totpImportPasswordHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) {
                    if (canImport) _import();
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.totpImportFormats,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: canImport ? _import : null,
          child: Text(l10n.commonImport),
        ),
      ],
    );
  }
}

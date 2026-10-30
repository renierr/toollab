import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/qr_codec.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/qr_scanner/qr_mlkit_camera_scanner.dart';

import '../totp_colors.dart';
import '../totp_import.dart';

/// Full-screen code scanner. Pops the raw payload once it parses as an
/// authenticator setup link (single account or Google Authenticator migration).
class TotpScanDialog extends StatefulWidget {
  const TotpScanDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TotpScanDialog(),
    );
  }

  @override
  State<TotpScanDialog> createState() => _TotpScanDialogState();
}

class _TotpScanDialogState extends State<TotpScanDialog> with DisposeCleanup {
  late final TempFileScope _scope;
  int _attempt = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
  }

  Future<void> _handlePayload(String text) async {
    if (_busy) return;
    _busy = true;
    try {
      await TotpImporter.parseText(text);
      if (!mounted) return;
      Navigator.of(context).pop(text);
    } on TotpImportException {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).totpNotOtpQr;
        _attempt++;
        _busy = false;
      });
    } catch (e) {
      errorLog('[TotpScanDialog] Invalid scan payload: $e');
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).totpNotOtpQr;
        _attempt++;
        _busy = false;
      });
    }
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      mimeTypes: ['image/*'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null || !mounted) return;

    QrDecodeResult? result;
    if (Platform.isAndroid) {
      result = await QrCodec.decodeImageFileMlKit(file.path);
    }
    result ??= await QrCodec.decodeImageFile(file.path);

    if (!mounted) return;
    if (result == null) {
      setState(() => _error = AppLocalizations.of(context).totpNoQrFound);
      return;
    }
    await _handlePayload(result.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = TotpAuthColors.accent;

    final Widget body;
    if (Platform.isAndroid) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          QrMlKitCameraScanner(
            key: ValueKey(_attempt),
            accentColor: accent,
            scope: _scope,
            onDetected: (text, _, _, _) => _handlePayload(text),
          ),
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.totpScanImageHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.totpChooseImage),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.totpScanTitle),
          leading: IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: body,
        bottomNavigationBar: Platform.isAndroid
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.totpScanHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(l10n.totpChooseImage),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

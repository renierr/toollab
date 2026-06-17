import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Renders the generated QR code (or a placeholder) plus save / copy / share
/// actions.
class QrPreviewPanel extends StatelessWidget {
  final Uint8List? pngBytes;
  final String? error;
  final Color accentColor;
  final TempFileScope scope;

  const QrPreviewPanel({
    super.key,
    required this.pngBytes,
    required this.error,
    required this.accentColor,
    required this.scope,
  });

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'qr_code.png',
      bytes: pngBytes,
      successMessageAndroid: l10n.qrSavedToDownloads,
      successMessageGeneralBuilder: (p) => l10n.qrSavedTo(p),
      errorMessageBuilder: (e) => l10n.qrSaveFailed(e),
    );
  }

  Future<void> _copyImage(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final codec = await ui.instantiateImageCodec(pngBytes!);
      final frame = await codec.getNextFrame();
      await ClipboardHelper.setImagePng(frame.image);
      frame.image.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.qrImageCopied)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.qrCopyImageFailed)));
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    final path = await scope.createFile('qr_code.png', bytes: pngBytes!);
    if (!context.mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'image/png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (pngBytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                error != null ? Icons.error_outline : Icons.qr_code_2,
                size: 72,
                color: error != null
                    ? theme.colorScheme.error
                    : accentColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                error ?? l10n.qrCreatePlaceholder,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: error != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 280,
                  maxHeight: 280,
                ),
                child: Image.memory(
                  pngBytes!,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _save(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(l10n.qrActionSave),
                  style: FilledButton.styleFrom(backgroundColor: accentColor),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyImage(context),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(l10n.qrActionCopyImage),
                ),
                OutlinedButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(l10n.qrActionShare),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

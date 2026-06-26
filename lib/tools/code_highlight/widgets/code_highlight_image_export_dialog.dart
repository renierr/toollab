import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'code_highlight_preview.dart';

class CodeHighlightImageExportDialog extends StatefulWidget {
  final String code;
  final String? fileName;
  final List<int> tokens;
  final List<String> scopes;

  const CodeHighlightImageExportDialog({
    super.key,
    required this.code,
    this.fileName,
    required this.tokens,
    required this.scopes,
  });

  @override
  State<CodeHighlightImageExportDialog> createState() =>
      _CodeHighlightImageExportDialogState();
}

class _CodeHighlightImageExportDialogState
    extends State<CodeHighlightImageExportDialog> {
  String _selectedFormat = 'PNG';
  final _exportBoundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      title: Row(
        children: [
          Text(l10n.codeHighlightExportImage),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.codeHighlightFormat}: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFormat,
                  dropdownColor: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  items: ['PNG', 'JPEG', 'WEBP']
                      .map(
                        (fmt) => DropdownMenuItem(value: fmt, child: Text(fmt)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedFormat = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.code.split('\n').length > 100) ...[
              InfoCard(
                icon: Icons.warning_amber_rounded,
                title: l10n.codeHighlightExportWarningTitle,
                titleColor: theme.colorScheme.error,
                borderColor: theme.colorScheme.error.withValues(alpha: 0.3),
                backgroundColor: theme.colorScheme.errorContainer.withValues(
                  alpha: 0.1,
                ),
                child: Text(
                  l10n.codeHighlightExportWarningMessage(
                    widget.code.split('\n').length,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
            ],
            RepaintBoundary(
              key: _exportBoundaryKey,
              child: CodeHighlightPreview(
                code: widget.code,
                tokens: widget.tokens,
                scopes: widget.scopes,
                fileName: widget.fileName,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton.icon(
          onPressed: _copyImage,
          icon: const Icon(Icons.copy),
          label: Text(l10n.codeHighlightCopyImage),
        ),
        ElevatedButton.icon(
          onPressed: _saveImage,
          icon: const Icon(Icons.download),
          label: Text(l10n.codeHighlightSaveImage),
        ),
      ],
    );
  }

  Future<void> _copyImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final boundary =
          _exportBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final success = await ClipboardHelper.copyImageBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? l10n.codeHighlightCopiedImage : l10n.sigCopyFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.codeHighlightFailedToCopyImage(e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _saveImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final boundary =
          _exportBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      Uint8List finalBytes = pngBytes;
      if (_selectedFormat == 'JPEG') {
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          finalBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
        }
      } else if (_selectedFormat == 'WEBP') {
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          finalBytes = Uint8List.fromList(img.encodeWebP(decoded));
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }

      final baseName = widget.fileName != null
          ? widget.fileName!.split('.').first
          : 'code';
      final ext = _selectedFormat.toLowerCase();
      if (mounted) {
        await FileSaveHelper.saveFile(
          context: context,
          suggestedName: '$baseName.$ext',
          bytes: finalBytes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.codeHighlightFailedToSaveImage(e.toString())),
          ),
        );
      }
    }
  }
}

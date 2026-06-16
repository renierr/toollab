import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';

class ImagesToPdfSettingsDrawer extends StatelessWidget {
  final ImageToPdfPageSize pageSize;
  final ValueChanged<ImageToPdfPageSize> onPageSizeChanged;
  final bool landscape;
  final ValueChanged<bool> onLandscapeChanged;
  final int jpegQuality;
  final ValueChanged<int> onJpegQualityChanged;
  final bool isProcessing;

  const ImagesToPdfSettingsDrawer({
    super.key,
    required this.pageSize,
    required this.onPageSizeChanged,
    required this.landscape,
    required this.onLandscapeChanged,
    required this.jpegQuality,
    required this.onJpegQualityChanged,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ImagesToPdfTool.config.accentColor;
    final l10n = AppLocalizations.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: accent, size: 36),
                      const Spacer(),
                      IconButton(
                        tooltip: l10n.commonClose,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.img2pdfPdfSettings,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.img2pdfPageSize,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ImageToPdfPageSize>(
                    initialValue: pageSize,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: isProcessing
                        ? null
                        : (v) {
                            if (v != null) onPageSizeChanged(v);
                          },
                    items: [
                      const DropdownMenuItem(
                        value: ImageToPdfPageSize.a4,
                        child: Text('A4'),
                      ),
                      const DropdownMenuItem(
                        value: ImageToPdfPageSize.letter,
                        child: Text('Letter'),
                      ),
                      const DropdownMenuItem(
                        value: ImageToPdfPageSize.legal,
                        child: Text('Legal'),
                      ),
                      DropdownMenuItem(
                        value: ImageToPdfPageSize.fit,
                        child: Text(l10n.img2pdfFitToImage),
                      ),
                    ],
                  ),
                  if (pageSize != ImageToPdfPageSize.fit) ...[
                    const SizedBox(height: 20),
                    Text(
                      l10n.img2pdfOrientation,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.img2pdfLandscape),
                      value: landscape,
                      onChanged: isProcessing ? null : onLandscapeChanged,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.img2pdfJpegQuality,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '$jpegQuality%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: jpegQuality.toDouble(),
                    min: 50,
                    max: 100,
                    divisions: 10,
                    label: '$jpegQuality%',
                    onChanged: isProcessing
                        ? null
                        : (v) => onJpegQualityChanged(v.round()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

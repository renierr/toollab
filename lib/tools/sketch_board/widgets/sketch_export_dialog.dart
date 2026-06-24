import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../models/sketch_enums.dart';

typedef SketchExportOptions = ({ExportFormat format, int quality});

/// Lets the user pick the export image format and (for lossy formats) quality.
Future<SketchExportOptions?> showSketchExportDialog(BuildContext context) {
  return showDialog<SketchExportOptions>(
    context: context,
    builder: (_) => const _ExportDialog(),
  );
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog();

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ExportFormat _format = ExportFormat.png;
  double _quality = 92;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.sketchExportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sketchExportFormat, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ExportFormat>(
            segments: [
              for (final f in ExportFormat.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 16),
          if (_format.isLossy) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.sketchExportQuality,
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  '${_quality.round()}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _quality,
              min: 10,
              max: 100,
              divisions: 18,
              label: '${_quality.round()}',
              onChanged: (v) => setState(() => _quality = v),
            ),
          ] else
            Text(
              l10n.sketchExportLossless,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((format: _format, quality: _quality.round())),
          child: Text(l10n.commonExport),
        ),
      ],
    );
  }
}

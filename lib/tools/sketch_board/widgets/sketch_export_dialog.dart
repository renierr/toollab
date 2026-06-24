import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../models/sketch_enums.dart';

typedef SketchExportOptions = ({
  ExportFormat format,
  int quality,
  double scale,
});

/// Encodes the drawing with the given options and returns the byte count, used
/// to preview the resulting file size.
typedef SketchSizeEstimator =
    Future<int?> Function(ExportFormat format, int quality, double scale);

/// Lets the user pick the export image format, resolution and (for lossy
/// formats) quality. [contentSize] is the padded content bounds in canvas units
/// (for the pixel-dimension preview); [estimate] encodes on demand to show the
/// resulting file size.
Future<SketchExportOptions?> showSketchExportDialog(
  BuildContext context,
  Size contentSize,
  SketchSizeEstimator estimate,
) {
  return showDialog<SketchExportOptions>(
    context: context,
    builder: (_) => _ExportDialog(contentSize: contentSize, estimate: estimate),
  );
}

class _ExportDialog extends StatefulWidget {
  final Size contentSize;
  final SketchSizeEstimator estimate;
  const _ExportDialog({required this.contentSize, required this.estimate});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  static const List<double> _scales = [1, 2, 4];

  ExportFormat _format = ExportFormat.png;
  double _quality = 92;
  double _scale = 2;

  int? _bytes;
  bool _estimating = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  String get _dimensions {
    final w = math.max(1, (widget.contentSize.width * _scale).ceil());
    final h = math.max(1, (widget.contentSize.height * _scale).ceil());
    return '$w × $h px';
  }

  Future<void> _recompute() async {
    final token = ++_token;
    setState(() => _estimating = true);
    final bytes = await widget.estimate(_format, _quality.round(), _scale);
    if (!mounted || token != _token) return;
    setState(() {
      _bytes = bytes;
      _estimating = false;
    });
  }

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
            onSelectionChanged: (s) {
              setState(() => _format = s.first);
              _recompute();
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.sketchExportResolution,
                style: theme.textTheme.labelLarge,
              ),
              Text(
                _dimensions,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: [
              for (final s in _scales)
                ButtonSegment(value: s, label: Text('${s.toInt()}×')),
            ],
            selected: {_scale},
            onSelectionChanged: (s) {
              setState(() => _scale = s.first);
              _recompute();
            },
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
              onChangeEnd: (_) => _recompute(),
            ),
          ] else
            Text(
              l10n.sketchExportLossless,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${l10n.sketchExportEstimatedSize}: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_estimating)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Text(
                  _bytes == null ? '—' : FormatHelper.fileSize(_bytes!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
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
          ).pop((format: _format, quality: _quality.round(), scale: _scale)),
          child: Text(l10n.commonExport),
        ),
      ],
    );
  }
}

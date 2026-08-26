import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_result_view.dart';

class PdfFlattenPanel extends StatefulWidget {
  final PdfOperationSession session;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfFlattenPanel({
    super.key,
    required this.session,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfFlattenPanel> createState() => _PdfFlattenPanelState();
}

enum _FlattenPhase { options, processing, done }

class _PdfFlattenPanelState extends State<PdfFlattenPanel> {
  _FlattenPhase _phase = _FlattenPhase.options;

  int _dpi = 200;
  int _jpegQuality = 90;

  double _progress = 0;
  String _statusText = '';
  String? _resultPath;
  int _resultSize = 0;
  int _totalPages = 0;

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  Future<void> _execute() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phase = _FlattenPhase.processing;
      _progress = 0;
    });

    PdfDocument? doc;
    try {
      doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
      _totalPages = doc.pages.length;

      final pdfBytes = await PdfEngineHelper.flattenPdfDocument(
        doc,
        dpi: _dpi,
        jpegQuality: _jpegQuality,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _progress = (done / total).clamp(0.0, 1.0);
              _statusText = l10n.pdfEditFlattenProgress(done, total);
            });
          }
        },
      ).timeout(const Duration(minutes: 5));

      // The result lives in the parent scope so it survives this panel being
      // disposed when the viewer reopens it.
      final resultPath = await widget.session.tempScope.createFile(
        '${_baseName}_flattened.pdf',
        bytes: pdfBytes,
      );

      if (!mounted) return;

      setState(() {
        _resultPath = resultPath;
        _resultSize = pdfBytes.length;
        _phase = _FlattenPhase.done;
        _progress = 1.0;
        _statusText = AppLocalizations.of(context).commonDone;
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _statusText = e.toString();
          _phase = _FlattenPhase.options;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pdfEditFlattenFailed(e.toString()))),
        );
      }
    } finally {
      doc?.dispose();
    }
  }

  Future<void> _download() async {
    final path = _resultPath;
    if (path == null) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: '${_baseName}_flattened.pdf',
      sourcePath: path,
    );
  }

  Future<void> _share() async {
    final path = _resultPath;
    if (path == null || !mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'application/pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditFlattenTitle(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: switch (_phase) {
        _FlattenPhase.options => _FlattenOptions(
          dpi: _dpi,
          jpegQuality: _jpegQuality,
          onDpiChanged: (v) => setState(() => _dpi = v),
          onJpegQualityChanged: (v) => setState(() => _jpegQuality = v),
          onStart: _execute,
        ),
        _FlattenPhase.processing => _FlattenProgress(
          progress: _progress,
          statusText: _statusText,
          totalPages: _totalPages,
        ),
        _FlattenPhase.done => PdfResultView(
          title: l10n.pdfEditFlattenDoneTitle,
          subtitle: l10n.pdfEditFlattenDoneSize(
            FormatHelper.fileSize(_resultSize),
          ),
          onDownload: _download,
          onShare: _share,
          onOpenInViewer: () =>
              widget.onComplete(_resultPath!, '${_baseName}_flattened.pdf'),
          onClose: widget.onCancel,
        ),
      },
    );
  }
}

class _FlattenOptions extends StatelessWidget {
  final int dpi;
  final int jpegQuality;
  final ValueChanged<int> onDpiChanged;
  final ValueChanged<int> onJpegQualityChanged;
  final VoidCallback onStart;

  const _FlattenOptions({
    required this.dpi,
    required this.jpegQuality,
    required this.onDpiChanged,
    required this.onJpegQualityChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.pdfEditFlattenHeadline, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          l10n.pdfEditFlattenDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _SliderCard(
          label: l10n.pdfEditFlattenDpi(dpi),
          hint: l10n.pdfEditFlattenDpiHint,
          value: dpi.toDouble(),
          min: 100,
          max: 400,
          divisions: 6,
          sliderLabel: '$dpi DPI',
          onChanged: (v) => onDpiChanged(v.round()),
        ),
        const SizedBox(height: 12),
        _SliderCard(
          label: l10n.pdfEditFlattenJpegQuality(jpegQuality),
          hint: l10n.pdfEditFlattenJpegQualityHint,
          value: jpegQuality.toDouble(),
          min: 50,
          max: 100,
          divisions: 10,
          sliderLabel: '$jpegQuality%',
          onChanged: (v) => onJpegQualityChanged(v.round()),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.photo_library),
          label: Text(l10n.pdfEditFlattenStart),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _SliderCard extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String sliderLabel;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.sliderLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: sliderLabel,
              onChanged: onChanged,
            ),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlattenProgress extends StatelessWidget {
  final double progress;
  final String statusText;
  final int totalPages;

  const _FlattenProgress({
    required this.progress,
    required this.statusText,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 24),
            Text(
              statusText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.pdfEditFlattenPagesTotal(totalPages),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

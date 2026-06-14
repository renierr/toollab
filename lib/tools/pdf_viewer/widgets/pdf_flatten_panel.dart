import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';

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
    setState(() {
      _phase = _FlattenPhase.processing;
      _progress = 0;
    });

    PdfDocument? doc;
    try {
      doc = await widget.session.openDocument();
      _totalPages = doc.pages.length;

      final pdfBytes = await PdfEngineHelper.flattenPdfDocument(
        doc,
        dpi: _dpi,
        jpegQuality: _jpegQuality,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _progress = (done / total).clamp(0.0, 1.0);
              _statusText = 'Rendering page $done of $total...';
            });
          }
        },
      );

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
        _statusText = 'Done';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Error: $e';
          _phase = _FlattenPhase.options;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Flatten failed: $e')));
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Flatten: ${widget.session.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _phase == _FlattenPhase.processing
              ? null
              : widget.onCancel,
        ),
      ),
      body: switch (_phase) {
        _FlattenPhase.options => _buildOptions(theme),
        _FlattenPhase.processing => _buildProgress(theme),
        _FlattenPhase.done => _buildDone(theme),
      },
    );
  }

  Widget _buildOptions(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Flatten PDF to Images', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Each page will be rendered as an image and embedded into a new PDF. '
          'This makes the content non-selectable and prevents text extraction.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // DPI
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolution (DPI): $_dpi',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _dpi.toDouble(),
                  min: 100,
                  max: 400,
                  divisions: 6,
                  label: '$_dpi DPI',
                  onChanged: (v) => setState(() => _dpi = v.round()),
                ),
                Text(
                  'Higher DPI = larger file size but better quality',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // JPEG Quality
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JPEG Quality: $_jpegQuality%',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _jpegQuality.toDouble(),
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '$_jpegQuality%',
                  onChanged: (v) => setState(() => _jpegQuality = v.round()),
                ),
                Text(
                  'Higher quality = larger file size',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: _execute,
          icon: const Icon(Icons.photo_library),
          label: const Text('Start Flattening'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 24),
            Text(
              _statusText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$_totalPages pages total',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    final size = _resultSize;
    final sizeText = size > 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : size > 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '$size B';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Flattening Complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'New PDF size: $sizeText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () =>
                  widget.onComplete(_resultPath!, '${_baseName}_flattened.pdf'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Viewer'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: widget.onCancel, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

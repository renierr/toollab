import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

class PdfFlattenPanel extends StatefulWidget {
  final String filePath;
  final String fileName;
  final void Function(Uint8List pdfBytes) onComplete;
  final VoidCallback onCancel;

  const PdfFlattenPanel({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfFlattenPanel> createState() => _PdfFlattenPanelState();
}

enum _FlattenPhase { options, processing, done }

class _PdfFlattenPanelState extends State<PdfFlattenPanel> with DisposeCleanup {
  _FlattenPhase _phase = _FlattenPhase.options;

  int _dpi = 200;
  int _jpegQuality = 90;
  String _format = 'jpeg';

  double _progress = 0;
  String _statusText = '';
  Uint8List? _resultBytes;
  int _totalPages = 0;

  late final TempFileScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
  }

  Future<void> _execute() async {
    setState(() {
      _phase = _FlattenPhase.processing;
      _progress = 0;
    });

    try {
      await _scope.cleanTracked();
      final doc = await PdfEngineHelper.openPdf(widget.filePath);
      _totalPages = doc.pages.length;
      final ext = _format == 'jpeg' ? 'jpg' : 'png';

      final pagePaths = <String>[];
      for (int i = 0; i < _totalPages; i++) {
        if (!mounted) {
          doc.dispose();
          return;
        }

        setState(() {
          _progress = (i / _totalPages).clamp(0.0, 1.0);
          _statusText = 'Rendering page ${i + 1} of $_totalPages...';
        });

        final bytes = await PdfEngineHelper.renderPageToBytes(
          doc.pages[i],
          dpi: _dpi,
          format: _format,
          jpegQuality: _jpegQuality,
        );
        pagePaths.add(await _scope.createFile('flatten_$i.$ext', bytes: bytes));
      }

      doc.dispose();

      if (!mounted) return;

      setState(() {
        _statusText = 'Creating PDF...';
      });

      final pdfBytes = await PdfEngineHelper.createPdfFromImagePaths(
        pagePaths,
        pageSize: ImageToPdfPageSize.fit,
        jpegQuality: _jpegQuality,
      );

      if (!mounted) return;

      setState(() {
        _resultBytes = pdfBytes;
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
    }
  }

  Future<void> _download() async {
    if (_resultBytes == null) return;
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: '${widget.fileName.replaceAll('.pdf', '')}_flattened.pdf',
      bytes: _resultBytes,
    );
  }

  Future<void> _share() async {
    if (_resultBytes == null) return;
    final path = await PdfEngineHelper.savePdfToTemp(
      _resultBytes!,
      '${widget.fileName.replaceAll('.pdf', '')}_flattened.pdf',
    );
    if (mounted) {
      await FileSaveHelper.showShareChooser(
        context: context,
        path: path,
        mimeType: 'application/pdf',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Flatten: ${widget.fileName}'),
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
                  min: 72,
                  max: 600,
                  divisions: 8,
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
        const SizedBox(height: 12),

        // Format
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image Format', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'jpeg',
                      label: Text('JPEG'),
                      icon: Icon(Icons.photo),
                    ),
                    ButtonSegment(
                      value: 'png',
                      label: Text('PNG'),
                      icon: Icon(Icons.image),
                    ),
                  ],
                  selected: {_format},
                  onSelectionChanged: (v) => setState(() => _format = v.first),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPEG is smaller, PNG is lossless but larger',
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
    final size = _resultBytes?.length ?? 0;
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
              onPressed: () => widget.onComplete(_resultBytes!),
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

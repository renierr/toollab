import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/services/signature_library.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';

import 'pdf_signature_picker.dart';
import 'pdf_signature_placement_overlay.dart';

/// A pending placement on a page, stored as page fractions so it survives
/// view resizes. [fw] is the width fraction; the height is derived from the
/// signature's aspect ratio and the page aspect ratio.
class _Placement {
  final SignatureRecord signature;
  double cx = 0.5;
  double cy = 0.5;
  double fw = 0.4;

  _Placement(this.signature);
}

enum _Phase { place, processing, done }

class PdfSignPanel extends StatefulWidget {
  final PdfOperationSession session;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfSignPanel({
    super.key,
    required this.session,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfSignPanel> createState() => _PdfSignPanelState();
}

class _PdfSignPanelState extends State<PdfSignPanel> with DisposeCleanup {
  PdfDocument? _doc;
  int _pageCount = 0;
  int _pageIndex = 0;
  bool _loading = true;

  List<SignatureRecord> _signatures = const [];
  final Map<int, Uint8List> _pageImages = {};
  final Map<int, _Placement> _placements = {};

  _Phase _phase = _Phase.place;
  String? _resultPath;
  int _resultSize = 0;

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    onDispose(() => _doc?.dispose());
    _init();
  }

  Future<void> _init() async {
    try {
      final doc = await widget.session.openDocument();
      final signatures = await SignatureLibrary.instance.getSignatures();
      if (!mounted) {
        doc.dispose();
        return;
      }
      _doc = doc;
      _pageCount = doc.pages.length;
      _signatures = signatures;
      await _renderPage(0);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open PDF: $e')));
        widget.onCancel();
      }
    }
  }

  Future<void> _renderPage(int index) async {
    if (_pageImages.containsKey(index) || _doc == null) return;
    final bytes = await PdfEngineHelper.renderPageToBytes(
      _doc!.pages[index],
      dpi: 220,
    );
    if (mounted) setState(() => _pageImages[index] = bytes);
  }

  double _pageAspect(int index) =>
      _doc!.pages[index].width / _doc!.pages[index].height;

  double _heightFraction(_Placement p, int index) {
    final ar = p.signature.width / p.signature.height;
    return p.fw * _pageAspect(index) / ar;
  }

  void _selectSignature(SignatureRecord record) {
    setState(() => _placements[_pageIndex] = _Placement(record));
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pageCount) return;
    setState(() => _pageIndex = index);
    _renderPage(index);
  }

  void _drag(Offset delta, double dispW, double dispH) {
    final p = _placements[_pageIndex];
    if (p == null) return;
    final fh = _heightFraction(p, _pageIndex);
    setState(() {
      p.cx = (p.cx + delta.dx / dispW).clamp(p.fw / 2, 1 - p.fw / 2);
      p.cy = (p.cy + delta.dy / dispH).clamp(fh / 2, 1 - fh / 2);
    });
  }

  void _resize(double deltaX, double dispW) {
    final p = _placements[_pageIndex];
    if (p == null) return;
    setState(() {
      var fw = ((p.fw * dispW + deltaX) / dispW).clamp(0.05, 1.0);
      p.fw = fw;
      var fh = _heightFraction(p, _pageIndex);
      if (fh > 1.0) {
        // Too tall to fit: cap width so the height fits exactly.
        final ar = p.signature.width / p.signature.height;
        p.fw = ar / _pageAspect(_pageIndex);
        fh = 1.0;
      }
      p.cx = p.cx.clamp(p.fw / 2, 1 - p.fw / 2);
      p.cy = p.cy.clamp(fh / 2, 1 - fh / 2);
    });
  }

  void _removeCurrent() {
    setState(() => _placements.remove(_pageIndex));
  }

  Future<void> _apply() async {
    final entries = _placements.entries.toList();
    if (entries.isEmpty || _doc == null) return;
    setState(() => _phase = _Phase.processing);
    try {
      final requests = <SignatureStampRequest>[];
      for (final entry in entries) {
        final index = entry.key;
        final p = entry.value;
        final png = await SignatureLibrary.instance.renderPng(p.signature);
        final fh = _heightFraction(p, index);
        requests.add(
          SignatureStampRequest(
            pageIndex: index,
            pngBytes: png,
            fx: p.cx - p.fw / 2,
            fy: p.cy - fh / 2,
            fw: p.fw,
            fh: fh,
          ),
        );
      }
      final bytes = await PdfEngineHelper.stampSignatureAnnotations(
        _doc!,
        requests,
      );
      final path = await widget.session.tempScope.createFile(
        '${_baseName}_signed.pdf',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _resultPath = path;
        _resultSize = bytes.length;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _phase = _Phase.place);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Signing failed: $e')));
      }
    }
  }

  Future<void> _download() async {
    final path = _resultPath;
    if (path == null) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: '${_baseName}_signed.pdf',
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
        title: Text('Sign: ${widget.session.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _phase == _Phase.processing ? null : widget.onCancel,
        ),
        actions: [
          if (_phase == _Phase.place)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Apply',
              onPressed: _placements.isEmpty ? null : _apply,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : switch (_phase) {
              _Phase.place => _buildPlace(theme),
              _Phase.processing => _buildProcessing(theme),
              _Phase.done => _buildDone(theme),
            },
    );
  }

  Widget _buildPlace(ThemeData theme) {
    return Column(
      children: [
        PdfSignaturePicker(
          signatures: _signatures,
          selectedId: _placements[_pageIndex]?.signature.shortId,
          onSelect: _selectSignature,
        ),
        const Divider(height: 1),
        Expanded(child: _buildPageView(theme)),
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildPageView(ThemeData theme) {
    final image = _pageImages[_pageIndex];
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final placement = _placements[_pageIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;
        final pageAspect = _pageAspect(_pageIndex);
        double dispW;
        double dispH;
        if (areaW / areaH > pageAspect) {
          dispH = areaH;
          dispW = dispH * pageAspect;
        } else {
          dispW = areaW;
          dispH = dispW / pageAspect;
        }
        final dispLeft = (areaW - dispW) / 2;
        final dispTop = (areaH - dispH) / 2;

        // Pointer deltas inside the transformed child are reported in the
        // child's (content) coordinate space, so overlay dragging keeps using
        // dispW/dispH regardless of the InteractiveViewer zoom level.
        return InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: SizedBox(
            width: areaW,
            height: areaH,
            child: Stack(
              children: [
                Positioned(
                  left: dispLeft,
                  top: dispTop,
                  width: dispW,
                  height: dispH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Image.memory(image, fit: BoxFit.fill),
                  ),
                ),
                if (placement != null)
                  _buildOverlay(placement, dispLeft, dispTop, dispW, dispH),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(
    _Placement p,
    double dispLeft,
    double dispTop,
    double dispW,
    double dispH,
  ) {
    final fh = _heightFraction(p, _pageIndex);
    final boxW = p.fw * dispW;
    final boxH = fh * dispH;
    final left = dispLeft + (p.cx - p.fw / 2) * dispW;
    final top = dispTop + (p.cy - fh / 2) * dispH;
    final image = p.signature.image;
    if (image == null) return const SizedBox.shrink();

    return Positioned(
      left: left,
      top: top,
      width: boxW,
      height: boxH,
      child: PdfSignaturePlacementOverlay(
        image: image,
        onDrag: (d) => _drag(d, dispW, dispH),
        onResize: (d) => _resize(d.dx, dispW),
        onRemove: _removeCurrent,
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final hasPlacement = _placements[_pageIndex] != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _pageIndex > 0
                  ? () => _goToPage(_pageIndex - 1)
                  : null,
              tooltip: 'Previous page',
            ),
            Text(
              'Page ${_pageIndex + 1} of $_pageCount',
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _pageIndex < _pageCount - 1
                  ? () => _goToPage(_pageIndex + 1)
                  : null,
              tooltip: 'Next page',
            ),
            const Spacer(),
            Text(
              hasPlacement
                  ? 'Drag to position · resize at corner'
                  : _signatures.isEmpty
                  ? ''
                  : 'Tap a signature above',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessing(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('Stamping signature...', style: theme.textTheme.titleMedium),
        ],
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
            Text('Signature Placed', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Signed PDF size: $sizeText',
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
                  widget.onComplete(_resultPath!, '${_baseName}_signed.pdf'),
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

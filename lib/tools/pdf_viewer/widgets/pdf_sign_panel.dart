import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/signature_library.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';

import 'pdf_result_view.dart';
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
  double rotation = 0;

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
      final doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pdfEditSignOpenError(e.toString()))),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _renderPage(int index) async {
    if (_pageImages.containsKey(index) || _doc == null) return;
    final bytes = await PdfEngineHelper.renderPageToBytes(
      _doc!.pages[index],
      dpi: 220,
    ).timeout(const Duration(seconds: 60));
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
            rotation: p.rotation,
          ),
        );
      }
      final bytes = await PdfEngineHelper.stampSignatureAnnotations(
        _doc!,
        requests,
      ).timeout(const Duration(minutes: 5));
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pdfEditSignFailed(e.toString()))),
        );
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditSignTitle(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          if (_phase == _Phase.place)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.commonApply,
              onPressed: _placements.isEmpty ? null : _apply,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : switch (_phase) {
              _Phase.place => Column(
                children: [
                  PdfSignaturePicker(
                    signatures: _signatures,
                    selectedId: _placements[_pageIndex]?.signature.shortId,
                    onSelect: _selectSignature,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _SignPageView(
                      image: _pageImages[_pageIndex],
                      pageAspect: _pageAspect(_pageIndex),
                      placement: _placements[_pageIndex],
                      heightFraction: (p) => _heightFraction(p, _pageIndex),
                      onDrag: _drag,
                      onResize: _resize,
                      onRotate: (p, a) => setState(() => p.rotation = a),
                      onRemove: _removeCurrent,
                    ),
                  ),
                  _SignBottomBar(
                    pageIndex: _pageIndex,
                    pageCount: _pageCount,
                    hasPlacement: _placements[_pageIndex] != null,
                    hasSignatures: _signatures.isNotEmpty,
                    onGoToPage: _goToPage,
                  ),
                ],
              ),
              _Phase.processing => const _SignProcessing(),
              _Phase.done => PdfResultView(
                title: l10n.pdfEditSignDoneTitle,
                subtitle: l10n.pdfEditSignDoneSize(
                  FormatHelper.fileSize(_resultSize),
                ),
                onDownload: _download,
                onShare: _share,
                onOpenInViewer: () =>
                    widget.onComplete(_resultPath!, '${_baseName}_signed.pdf'),
                onClose: widget.onCancel,
              ),
            },
    );
  }
}

class _SignPageView extends StatelessWidget {
  final Uint8List? image;
  final double pageAspect;
  final _Placement? placement;
  final double Function(_Placement p) heightFraction;
  final void Function(Offset delta, double dispW, double dispH) onDrag;
  final void Function(double deltaX, double dispW) onResize;
  final void Function(_Placement p, double angle) onRotate;
  final VoidCallback onRemove;

  const _SignPageView({
    required this.image,
    required this.pageAspect,
    required this.placement,
    required this.heightFraction,
    required this.onDrag,
    required this.onResize,
    required this.onRotate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = image;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final current = placement;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;
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
                    child: Image.memory(bytes, fit: BoxFit.fill),
                  ),
                ),
                if (current != null)
                  _PlacementOverlay(
                    placement: current,
                    heightFraction: heightFraction(current),
                    dispLeft: dispLeft,
                    dispTop: dispTop,
                    dispW: dispW,
                    dispH: dispH,
                    onDrag: (d) => onDrag(d, dispW, dispH),
                    onResize: (d) => onResize(d.dx, dispW),
                    onRotate: (a) => onRotate(current, a),
                    onRemove: onRemove,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlacementOverlay extends StatelessWidget {
  final _Placement placement;
  final double heightFraction;
  final double dispLeft;
  final double dispTop;
  final double dispW;
  final double dispH;
  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onResize;
  final ValueChanged<double> onRotate;
  final VoidCallback onRemove;

  const _PlacementOverlay({
    required this.placement,
    required this.heightFraction,
    required this.dispLeft,
    required this.dispTop,
    required this.dispW,
    required this.dispH,
    required this.onDrag,
    required this.onResize,
    required this.onRotate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final image = placement.signature.image;
    if (image == null) return const SizedBox.shrink();

    // Inflate the positioned box by the overlay margins so the handles render
    // inside the widget's bounds (the top margin is larger to host the rotate
    // handle above the box).
    const side = PdfSignaturePlacementOverlay.sideMargin;
    const top = PdfSignaturePlacementOverlay.topMargin;
    final boxW = placement.fw * dispW;
    final boxH = heightFraction * dispH;
    final boxLeft = dispLeft + (placement.cx - placement.fw / 2) * dispW;
    final boxTop = dispTop + (placement.cy - heightFraction / 2) * dispH;

    return Positioned(
      left: boxLeft - side,
      top: boxTop - top,
      width: boxW + 2 * side,
      height: boxH + top + side,
      child: PdfSignaturePlacementOverlay(
        image: image,
        rotation: placement.rotation,
        onDrag: onDrag,
        onResize: onResize,
        onRotate: onRotate,
        onRemove: onRemove,
      ),
    );
  }
}

class _SignBottomBar extends StatelessWidget {
  final int pageIndex;
  final int pageCount;
  final bool hasPlacement;
  final bool hasSignatures;
  final ValueChanged<int> onGoToPage;

  const _SignBottomBar({
    required this.pageIndex,
    required this.pageCount,
    required this.hasPlacement,
    required this.hasSignatures,
    required this.onGoToPage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: pageIndex > 0 ? () => onGoToPage(pageIndex - 1) : null,
              tooltip: l10n.pdfEditSignPrevPage,
            ),
            Text(
              l10n.pdfEditSignPageOf(pageIndex + 1, pageCount),
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: pageIndex < pageCount - 1
                  ? () => onGoToPage(pageIndex + 1)
                  : null,
              tooltip: l10n.pdfEditSignNextPage,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPlacement
                    ? l10n.pdfEditSignDragHint
                    : !hasSignatures
                    ? ''
                    : l10n.pdfEditSignTapHint,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignProcessing extends StatelessWidget {
  const _SignProcessing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(l10n.pdfEditSignStamping, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

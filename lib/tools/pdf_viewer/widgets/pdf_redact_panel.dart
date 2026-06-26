import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';

import 'pdf_redact_overlay.dart';

enum _InputMode { draw, select }

enum _Phase { edit, processing, done }

class PdfRedactPanel extends StatefulWidget {
  final PdfOperationSession session;
  final PdfTextSelection? initialTextSelection;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfRedactPanel({
    super.key,
    required this.session,
    this.initialTextSelection,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfRedactPanel> createState() => _PdfRedactPanelState();
}

class _PdfRedactPanelState extends State<PdfRedactPanel> with DisposeCleanup {
  PdfDocument? _doc;
  int _pageCount = 0;
  int _pageIndex = 0;
  bool _loading = true;

  _InputMode _inputMode = _InputMode.draw;
  bool _isDrawing = false;
  _Phase _phase = _Phase.edit;

  final Map<int, Uint8List> _pageImages = {};
  final Map<int, List<Rect>> _redactionMarks = {};

  PdfTextSelection? _textSelection;
  bool _hasTextSelection = false;

  String? _resultPath;
  int _resultSize = 0;

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _doc?.dispose();
    });
    _init();
  }

  Future<void> _init() async {
    try {
      final doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted) {
        doc.dispose();
        return;
      }
      _doc = doc;
      _pageCount = doc.pages.length;
      _redactionMarks.clear();
      for (int i = 0; i < _pageCount; i++) {
        _redactionMarks[i] = [];
      }

      int initialPageIndex = 0;
      final initialSel = widget.initialTextSelection;
      if (initialSel != null && initialSel.hasSelectedText) {
        final ranges = await initialSel.getSelectedTextRanges();
        if (ranges.isNotEmpty) {
          initialPageIndex = (ranges.first.pageNumber - 1).clamp(
            0,
            _pageCount - 1,
          );
        }
        for (final range in ranges) {
          final pdfRect = range.bounds;
          final pageIdx = range.pageNumber - 1;
          if (pageIdx >= 0 && pageIdx < _pageCount) {
            final rect = Rect.fromLTRB(
              pdfRect.left,
              pdfRect.bottom,
              pdfRect.right,
              pdfRect.top,
            );
            _redactionMarks[pageIdx]!.add(rect);
          }
        }
      }

      _pageIndex = initialPageIndex;
      await _renderPage(_pageIndex);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pdfEditRedactFailed(e.toString()))),
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

  void _goToPage(int index) {
    if (index < 0 || index >= _pageCount) return;
    setState(() => _pageIndex = index);
    _renderPage(index);
  }

  Rect _fracToPdfRect(Rect frac) {
    final pw = _doc!.pages[_pageIndex].width;
    final ph = _doc!.pages[_pageIndex].height;
    return Rect.fromLTRB(
      frac.left * pw,
      (1 - frac.bottom) * ph,
      frac.right * pw,
      (1 - frac.top) * ph,
    );
  }

  void _addMark(Rect fracRect) {
    final pdfRect = _fracToPdfRect(fracRect);
    setState(() {
      _redactionMarks[_pageIndex]!.add(pdfRect);
    });
  }

  void _removeMark(int index) {
    final marks = _redactionMarks[_pageIndex]!;
    if (index >= 0 && index < marks.length) {
      setState(() => marks.removeAt(index));
    }
  }

  void _inputModeChanged(_InputMode mode) {
    if (mode == _inputMode) return;
    setState(() {
      _inputMode = mode;
      _hasTextSelection = false;
    });
  }

  void _onTextSelectionChange(PdfTextSelection selection) {
    final has = selection.hasSelectedText;
    if (has != _hasTextSelection) {
      setState(() {
        _hasTextSelection = has;
        if (has) _textSelection = selection;
      });
    }
  }

  Future<void> _redactSelectedText() async {
    final sel = _textSelection;
    if (sel == null) return;
    final ranges = await sel.getSelectedTextRanges();
    if (ranges.isEmpty) return;

    for (final range in ranges) {
      final pdfRect = range.bounds;
      final pageIdx = range.pageNumber - 1;
      if (pageIdx < 0 || pageIdx >= _pageCount) continue;
      final rect = Rect.fromLTRB(
        pdfRect.left,
        pdfRect.bottom,
        pdfRect.right,
        pdfRect.top,
      );
      _redactionMarks[pageIdx] ??= [];
      _redactionMarks[pageIdx]!.add(rect);
    }

    setState(() {
      _inputMode = _InputMode.draw;
      _hasTextSelection = false;
    });
    _renderPage(_pageIndex);
  }

  int get _totalMarkCount =>
      _redactionMarks.values.fold(0, (s, l) => s + l.length);

  Future<void> _apply() async {
    if (_totalMarkCount == 0 || _doc == null) return;
    setState(() => _phase = _Phase.processing);
    try {
      final marksToApply = Map<int, List<Rect>>.from(
        _redactionMarks.map((k, v) => MapEntry(k, List<Rect>.from(v))),
      );
      final bytes = await PdfEngineHelper.redactPdfDocument(
        _doc!,
        marksToApply,
        onProgress: (done, total) {},
      );
      final path = await widget.session.tempScope.createFile(
        '${_baseName}_redacted.pdf',
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
        setState(() => _phase = _Phase.edit);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pdfEditRedactFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _download() async {
    final path = _resultPath;
    if (path == null) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: '${_baseName}_redacted.pdf',
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
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.pdfEditRedactTitle(widget.session.fileName)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return switch (_phase) {
      _Phase.edit => _buildEdit(theme, l10n),
      _Phase.processing => _buildProcessing(theme, l10n),
      _Phase.done => _buildDone(theme, l10n),
    };
  }

  Widget _buildEdit(ThemeData theme, AppLocalizations l10n) {
    return Scaffold(
      appBar: _buildEditAppBar(theme, l10n),
      body: _inputMode == _InputMode.draw
          ? _buildDrawMode(theme)
          : _buildSelectMode(theme, l10n),
    );
  }

  PreferredSizeWidget _buildEditAppBar(ThemeData theme, AppLocalizations l10n) {
    return AppBar(
      title: Text(l10n.pdfEditRedactTitle(widget.session.fileName)),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: widget.onCancel,
      ),
      actions: [
        if (_inputMode == _InputMode.select)
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: l10n.pdfEditRedactRedactSelected,
            onPressed: _hasTextSelection ? _redactSelectedText : null,
          ),
        if (_inputMode == _InputMode.select)
          IconButton(
            icon: const Icon(Icons.draw),
            tooltip: l10n.pdfEditRedactModeDraw,
            onPressed: () => _inputModeChanged(_InputMode.draw),
          ),
        if (_inputMode == _InputMode.draw)
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: l10n.pdfEditRedactModeSelect,
            onPressed: () => _inputModeChanged(_InputMode.select),
          ),
        if (_inputMode == _InputMode.draw)
          IconButton(
            icon: Icon(
              Icons.check,
              color: _totalMarkCount > 0
                  ? null
                  : theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            tooltip: l10n.commonApply,
            onPressed: _totalMarkCount > 0 ? _apply : null,
          ),
      ],
    );
  }

  Widget _buildDrawMode(ThemeData theme) {
    final image = _pageImages[_pageIndex];
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final marks = _redactionMarks[_pageIndex] ?? [];
    final marksFrac = marks.map(_pdfRectToFrac).toList();

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final areaW = constraints.maxWidth;
              final areaH = constraints.maxHeight;
              final pageAspect = _pageAspect(_pageIndex);
              final dispW = areaW;
              final dispH = dispW / pageAspect;
              final dispLeft = 0.0;
              final dispTop = dispH < areaH ? (areaH - dispH) / 2 : 0.0;

              return InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                constrained: false,
                child: SizedBox(
                  width: areaW,
                  height: max(areaH, dispH),
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
                      PdfRedactOverlay(
                        marks: marksFrac,
                        dispLeft: dispLeft,
                        dispTop: dispTop,
                        dispW: dispW,
                        dispH: dispH,
                        onDeleteMark: _removeMark,
                        onNewMark: _addMark,
                        isDrawing: _isDrawing,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildBottomBar(theme),
      ],
    );
  }

  Rect _pdfRectToFrac(Rect pdf) {
    final pw = _doc!.pages[_pageIndex].width;
    final ph = _doc!.pages[_pageIndex].height;
    return Rect.fromLTRB(
      pdf.left / pw,
      (ph - pdf.top) / ph,
      pdf.right / pw,
      (ph - pdf.bottom) / ph,
    );
  }

  Widget _buildSelectMode(ThemeData theme, AppLocalizations l10n) {
    return PdfViewer.file(
      widget.session.filePath,
      passwordProvider: widget.session.passwordProvider,
      params: PdfViewerParams(
        textSelectionParams: PdfTextSelectionParams(
          enabled: true,
          onTextSelectionChange: _onTextSelectionChange,
        ),
        onViewerReady: (doc, ctrl) {},
        getPageRenderingScale: (ctx, page, ctrl, estimated) {
          final scale = estimated.clamp(1.0, 3.0);
          return scale;
        },
        maxImageBytesCachedOnMemory: 128 * 1024 * 1024,
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
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
            ),
            Text(
              l10n.pdfEditRedactPageOf(_pageIndex + 1, _pageCount),
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _pageIndex < _pageCount - 1
                  ? () => _goToPage(_pageIndex + 1)
                  : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(_isDrawing ? Icons.edit : Icons.pan_tool_outlined),
              tooltip: _isDrawing
                  ? l10n.pdfEditRedactModeNavigate
                  : l10n.pdfEditRedactModeDraw,
              onPressed: () => setState(() => _isDrawing = !_isDrawing),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _totalMarkCount > 0
                    ? l10n.pdfEditRedactDrawHint
                    : l10n.pdfEditRedactSelectHint,
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

  Widget _buildProcessing(ThemeData theme, AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditRedactTitle(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              l10n.pdfEditRedactProcessing,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme, AppLocalizations l10n) {
    final size = _resultSize;
    final sizeText = size > 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : size > 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '$size B';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditRedactTitle(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: Center(
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
              Text(
                l10n.pdfEditRedactDoneTitle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pdfEditRedactDoneSize(sizeText),
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
                    label: Text(l10n.pdfEditDownload),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: Text(l10n.commonShare),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => widget.onComplete(
                  _resultPath!,
                  '${_baseName}_redacted.pdf',
                ),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.pdfEditOpenInViewer),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.commonClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

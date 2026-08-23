import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';

import 'pdf_redact_done_page.dart';
import 'pdf_redact_draw_view.dart';
import 'pdf_redact_edit_appbar.dart';
import 'pdf_redact_find_dialog.dart';
import 'pdf_redact_processing_page.dart';
import 'pdf_redact_select_view.dart';

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

  PdfRedactEditMode _inputMode = PdfRedactEditMode.draw;
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
      _pageImages.clear();
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

  void _inputModeChanged(PdfRedactEditMode mode) {
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
      _inputMode = PdfRedactEditMode.draw;
      _hasTextSelection = false;
    });
    _renderPage(_pageIndex);
  }

  int get _totalMarkCount =>
      _redactionMarks.values.fold(0, (s, l) => s + l.length);

  Future<void> _findAndMarkAll() async {
    final query = await PdfRedactFindDialog.show(context);
    if (query == null || _doc == null || !mounted) return;

    var count = 0;
    try {
      for (final page in _doc!.pages) {
        final pageText = await page.loadStructuredText();
        await for (final match in pageText.allMatches(query)) {
          final pageIdx = page.pageNumber - 1;
          for (final frag in match.enumerateFragmentBoundingRects()) {
            final pdfRect = frag.bounds;
            _redactionMarks[pageIdx]!.add(
              Rect.fromLTRB(
                pdfRect.left,
                pdfRect.bottom,
                pdfRect.right,
                pdfRect.top,
              ),
            );
            count++;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).pdfEditRedactFailed(e.toString()),
          ),
        ),
      );
    }
    if (!mounted) return;
    await _renderPage(_pageIndex);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).pdfEditRedactFoundCount(count),
        ),
      ),
    );
  }

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
      _Phase.edit => _editScaffold(l10n),
      _Phase.processing => PdfRedactProcessingPage(
        fileName: widget.session.fileName,
        onClose: widget.onCancel,
      ),
      _Phase.done => PdfRedactDonePage(
        fileName: widget.session.fileName,
        resultSize: _resultSize,
        onDownload: _download,
        onShare: _share,
        onOpen: () =>
            widget.onComplete(_resultPath!, '${_baseName}_redacted.pdf'),
        onClose: widget.onCancel,
      ),
    };
  }

  Scaffold _editScaffold(AppLocalizations l10n) {
    return Scaffold(
      appBar: PdfRedactEditAppBar(
        fileName: widget.session.fileName,
        mode: _inputMode,
        hasTextSelection: _hasTextSelection,
        totalMarkCount: _totalMarkCount,
        onCancel: widget.onCancel,
        onModeChange: () => _inputModeChanged(
          _inputMode == PdfRedactEditMode.draw
              ? PdfRedactEditMode.select
              : PdfRedactEditMode.draw,
        ),
        onRedactSelected: _redactSelectedText,
        onFind: _findAndMarkAll,
        onApply: _apply,
      ),
      body: _inputMode == PdfRedactEditMode.draw
          ? _pageImages[_pageIndex] == null
                ? const Center(child: CircularProgressIndicator())
                : PdfRedactDrawView(
                    pageImage: _pageImages[_pageIndex]!,
                    marksFrac: _redactionMarks[_pageIndex]!
                        .map(_pdfRectToFrac)
                        .toList(),
                    pageAspect: _pageAspect(_pageIndex),
                    pageIndex: _pageIndex,
                    pageCount: _pageCount,
                    totalMarkCount: _totalMarkCount,
                    isDrawing: _isDrawing,
                    onNewMark: _addMark,
                    onDeleteMark: _removeMark,
                    onPrevPage: () => _goToPage(_pageIndex - 1),
                    onNextPage: () => _goToPage(_pageIndex + 1),
                    onToggleDraw: () =>
                        setState(() => _isDrawing = !_isDrawing),
                  )
          : PdfRedactSelectView(
              filePath: widget.session.filePath,
              passwordProvider: widget.session.passwordProvider,
              onTextSelectionChange: _onTextSelectionChange,
            ),
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
}

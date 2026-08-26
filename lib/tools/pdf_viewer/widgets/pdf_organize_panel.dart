import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_result_view.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class PdfOrganizePanel extends StatefulWidget {
  final PdfOperationSession session;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfOrganizePanel({
    super.key,
    required this.session,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfOrganizePanel> createState() => _PdfOrganizePanelState();
}

enum _OrganizePhase { editing, processing, done }

class _PdfOrganizePanelState extends State<PdfOrganizePanel> {
  PdfDocument? _doc;
  final List<PdfDocument> _insertedDocs = [];
  List<_PageItem> _pages = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  _OrganizePhase _phase = _OrganizePhase.editing;
  String? _resultPath;
  int _resultSize = 0;

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _doc?.dispose();
    for (final doc in _insertedDocs) {
      doc.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
      final pages = <_PageItem>[];
      for (int i = 0; i < doc.pages.length; i++) {
        pages.add(_PageItem(index: i, page: doc.pages[i]));
      }
      if (mounted) {
        setState(() {
          _doc = doc;
          _pages = pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).pdfNavOrganizeLoadFailed(e.toString()),
            ),
          ),
        );
        widget.onCancel();
      }
    }
  }

  void _removePage(int index) {
    final l10n = AppLocalizations.of(context);
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pdfNavOrganizeCannotDeleteLastPage)),
      );
      return;
    }
    ConfirmActionDialog.show(
      context: context,
      title: l10n.pdfNavOrganizeRemovePageTitle,
      message: l10n.pdfNavOrganizeRemovePageMessage(index + 1),
      confirmLabel: l10n.commonRemove,
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        setState(() => _pages.removeAt(index));
      }
    });
  }

  Future<void> _insertPages() async {
    final xFile = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (xFile == null || !mounted) return;

    try {
      setState(() => _isProcessing = true);

      final insertDoc = await PdfEngineHelper.openPdf(
        xFile.path,
      ).timeout(const Duration(seconds: 30));
      final srcPages = insertDoc.pages.toList();

      if (mounted) {
        _showInsertDialog(srcPages, insertDoc, xFile.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).pdfNavOrganizeOpenFailed(e.toString()),
            ),
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInsertDialog(
    List<PdfPage> srcPages,
    PdfDocument srcDoc,
    String srcName,
  ) {
    final selected = <int>{};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l10n = AppLocalizations.of(ctx);
          return ResponsiveAlertDialog(
            title: Text(l10n.pdfNavOrganizeInsertDialogTitle(srcName)),
            content: SizedBox(
              width: 360,
              height: 400,
              child: srcPages.isEmpty
                  ? Center(child: Text(l10n.pdfNavOrganizeNoPagesFound))
                  : ListView.builder(
                      itemCount: srcPages.length,
                      itemBuilder: (_, i) {
                        final p = srcPages[i];
                        final isPortrait = p.height >= p.width;
                        return CheckboxListTile(
                          value: selected.contains(i),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selected.add(i);
                              } else {
                                selected.remove(i);
                              }
                            });
                          },
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 44,
                              height: 58,
                              child: PdfPageView(
                                document: p.document,
                                pageNumber: p.pageNumber,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                          title: Text(l10n.pdfNavOrganizePageNumber(i + 1)),
                          subtitle: Text(
                            '${p.width.round()} x ${p.height.round()} pt · '
                            '${isPortrait ? l10n.pdfNavOrientationPortrait : l10n.pdfNavOrientationLandscape}',
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    if (selected.length == srcPages.length) {
                      selected.clear();
                    } else {
                      selected.addAll(List.generate(srcPages.length, (i) => i));
                    }
                  });
                },
                child: Text(
                  selected.length == srcPages.length
                      ? l10n.pdfNavDeselectAll
                      : l10n.pdfNavSelectAll,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _isProcessing = false);
                },
                child: Text(l10n.commonClose),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop(selected.toList());
                },
                child: Text(l10n.pdfNavOrganizeInsertCount(selected.length)),
              ),
            ],
          );
        },
      ),
    ).then((result) {
      // Keep the source document alive: page import happens lazily at
      // encodePdf() time, so disposing it now would yield blank pages.
      if (result is List<int> && result.isNotEmpty && mounted) {
        _insertedDocs.add(srcDoc);
        setState(() {
          for (final idx in result) {
            _pages.add(_PageItem(index: -1, page: srcPages[idx]));
          }
          _isProcessing = false;
        });
      } else {
        srcDoc.dispose();
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> _apply() async {
    if (_doc == null || _pages.isEmpty) return;
    setState(() {
      _phase = _OrganizePhase.processing;
      _isProcessing = true;
    });
    try {
      final newDoc = await PdfDocument.createNew(sourceName: 'organized.pdf');
      newDoc.pages = _pages.map((p) => p.page).toList();
      final bytes = await newDoc.encodePdf().timeout(
        const Duration(minutes: 5),
      );
      newDoc.dispose();

      // Stage to the parent scope so the result survives this panel closing.
      final resultPath = await widget.session.tempScope.createFile(
        '${_baseName}_organized.pdf',
        bytes: bytes,
      );

      if (mounted) {
        setState(() {
          _resultPath = resultPath;
          _resultSize = bytes.length;
          _phase = _OrganizePhase.done;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _OrganizePhase.editing;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).pdfNavOrganizeReorganizeFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _download() async {
    final path = _resultPath;
    if (path == null) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: '${_baseName}_organized.pdf',
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_phase == _OrganizePhase.done && _resultPath != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.pdfNavOrganizeTitle(widget.session.fileName)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel,
          ),
        ),
        body: PdfResultView(
          title: l10n.pdfNavOrganizeComplete,
          subtitle: l10n.pdfNavOrganizeNewSize(
            PdfResultView.formatSize(_resultSize),
          ),
          onDownload: _download,
          onShare: _share,
          onOpenInViewer: () =>
              widget.onComplete(_resultPath!, '${_baseName}_organized.pdf'),
          onClose: widget.onCancel,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfNavOrganizeTitle(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.pdfNavOrganizeInsertTooltip,
            onPressed: _isProcessing ? null : _insertPages,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.pdfNavOrganizeApplyTooltip,
            onPressed: _isProcessing ? null : _apply,
          ),
        ],
      ),
      body: _phase == _OrganizePhase.processing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.pdfNavOrganizePageCountHint(_pages.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _pages.isEmpty
                      ? Center(child: Text(l10n.pdfNavOrganizeNoPages))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(8),
                          buildDefaultDragHandles: false,
                          itemCount: _pages.length,
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final item = _pages.removeAt(oldIndex);
                              _pages.insert(newIndex, item);
                            });
                          },
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final item = _pages[index];
                            return _PageTile(
                              key: ValueKey('page_${item.identifier}_$index'),
                              index: index,
                              page: item.page,
                              onRemove: () => _removePage(index),
                              theme: theme,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _PageItem {
  final int index;
  final PdfPage page;
  final String identifier;

  _PageItem({required this.index, required this.page})
    : identifier = '${page.document.sourceName}_${page.pageNumber}';
}

class _PageTile extends StatelessWidget {
  final int index;
  final PdfPage page;
  final VoidCallback onRemove;
  final ThemeData theme;

  const _PageTile({
    super.key,
    required this.index,
    required this.page,
    required this.onRemove,
    required this.theme,
  });

  void _showPreview(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final l10n = AppLocalizations.of(context);
    final aspect = page.width / page.height;
    double w = media.width * 0.8;
    double h = w / aspect;
    final maxH = media.height * 0.6;
    if (h > maxH) {
      h = maxH;
      w = h * aspect;
    }

    showDialog(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                l10n.pdfNavOrganizePageNumber(index + 1),
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: w,
          height: h,
          child: InteractiveViewer(
            maxScale: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PdfPageView(
                document: page.document,
                pageNumber: page.pageNumber,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
        scrollable: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPreview(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 56,
                  height: 72,
                  child: PdfPageView(
                    document: page.document,
                    pageNumber: page.pageNumber,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pdfNavOrganizePageNumber(index + 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      '${page.width.round()} x ${page.height.round()} pt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outlined,
                  color: theme.colorScheme.error,
                ),
                tooltip: l10n.commonRemove,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

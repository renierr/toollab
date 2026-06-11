import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class PdfOrganizePanel extends StatefulWidget {
  final String filePath;
  final String fileName;
  final TempFileScope tempScope;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfOrganizePanel({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.tempScope,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfOrganizePanel> createState() => _PdfOrganizePanelState();
}

enum _OrganizePhase { editing, processing, done }

class _PdfOrganizePanelState extends State<PdfOrganizePanel> {
  PdfDocument? _doc;
  List<_PageItem> _pages = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  _OrganizePhase _phase = _OrganizePhase.editing;
  String? _resultPath;
  int _resultSize = 0;

  String get _baseName => widget.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await PdfEngineHelper.openPdf(widget.filePath);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
        widget.onCancel();
      }
    }
  }

  void _removePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last page')),
      );
      return;
    }
    ConfirmActionDialog.show(
      context: context,
      title: 'Remove Page',
      message: 'Remove page ${index + 1}?',
      confirmLabel: 'Remove',
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

      final insertDoc = await PdfEngineHelper.openPdf(xFile.path);
      final srcPages = insertDoc.pages.toList();

      if (mounted) {
        _showInsertDialog(srcPages, insertDoc, xFile.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open PDF: $e')));
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
        builder: (ctx, setDialogState) => ResponsiveAlertDialog(
          title: Text('Insert Pages from "$srcName"'),
          content: SizedBox(
            width: 360,
            height: 400,
            child: srcPages.isEmpty
                ? const Center(child: Text('No pages found'))
                : ListView.builder(
                    itemCount: srcPages.length,
                    itemBuilder: (_, i) => CheckboxListTile(
                      value: selected.contains(i),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selected.add(i);
                          } else {
                            selected.remove(i);
                          }
                        });
                      },
                      title: Text('Page ${i + 1}'),
                      subtitle: Text(
                        '${srcPages[i].width.round()} x ${srcPages[i].height.round()} pt',
                      ),
                    ),
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
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _isProcessing = false);
              },
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(selected.toList());
              },
              child: Text(
                'Insert ${selected.length} page${selected.length == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),
      ),
    ).then((result) {
      srcDoc.dispose();
      if (result is List<int> && result.isNotEmpty && mounted) {
        setState(() {
          for (final idx in result) {
            _pages.add(_PageItem(index: -1, page: srcPages[idx]));
          }
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
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
      final bytes = await newDoc.encodePdf();
      newDoc.dispose();

      // Stage to the parent scope so the result survives this panel closing.
      final resultPath = await widget.tempScope.createFile(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reorganize: $e')));
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_phase == _OrganizePhase.done && _resultPath != null) {
      return _buildDone(theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Organize: ${widget.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isProcessing ? null : widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Insert pages from another PDF',
            onPressed: _isProcessing ? null : _insertPages,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Apply changes',
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
                        '${_pages.length} page${_pages.length == 1 ? '' : 's'} — '
                        'drag to reorder, tap X to remove',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _pages.isEmpty
                      ? const Center(child: Text('No pages'))
                      : ReorderableListView.builder(
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

  Widget _buildDone(ThemeData theme) {
    final size = _resultSize;
    final sizeText = size > 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : size > 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '$size B';

    return Scaffold(
      appBar: AppBar(
        title: Text('Organize: ${widget.fileName}'),
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
              Text('Organizing Complete', style: theme.textTheme.headlineSmall),
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
                onPressed: () => widget.onComplete(
                  _resultPath!,
                  '${_baseName}_organized.pdf',
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in Viewer'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Close'),
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 80,
          child: PdfPageView(
            document: page.document,
            pageNumber: page.pageNumber,
            alignment: Alignment.center,
          ),
        ),
        title: Text('Page ${index + 1}'),
        subtitle: Text('${page.width.round()} x ${page.height.round()} pt'),
        trailing: IconButton(
          icon: Icon(
            Icons.remove_circle_outlined,
            color: theme.colorScheme.error,
          ),
          tooltip: 'Remove page',
          onPressed: onRemove,
        ),
        onTap: () {},
      ),
    );
  }
}

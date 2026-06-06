import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_drop_zone.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_display.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_overlay_controls.dart';
import 'package:tool_lab/tools/pdf_viewer/layout_mode.dart';

class PdfViewerPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const PdfViewerPage({super.key, this.sharedFile});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> with DisposeCleanup {
  late final PdfViewerController _pdfController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _filePath;
  String? _fileName;
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> _totalPagesNotifier = ValueNotifier<int>(0);
  bool _showOverlays = true;

  // Bookmarks/Outline
  List<PdfOutlineNode>? _outline;
  bool _isLoadingOutline = false;

  // Search State
  PdfTextSearcher? _pdfTextSearcher;
  bool _isSearchingText = false;
  final TextEditingController _searchTextController = TextEditingController();
  int _currentMatchIndex = 0;
  int _totalMatches = 0;

  // Layout mode
  PdfLayoutMode _layoutMode = PdfLayoutMode.vertical;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();

    _searchTextController.addListener(_onSearchTextChanged);

    onDispose(() {
      _pdfTextSearcher?.removeListener(_onSearchChanged);
      _pdfTextSearcher?.dispose();
      _searchTextController.dispose();
      _currentPageNotifier.dispose();
      _totalPagesNotifier.dispose();
    });

    if (widget.sharedFile != null) {
      _filePath = widget.sharedFile!.path;
      _fileName = widget.sharedFile!.name;
    }
  }

  @override
  void didUpdateWidget(covariant PdfViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedFile != oldWidget.sharedFile &&
        widget.sharedFile != null) {
      _pdfTextSearcher?.removeListener(_onSearchChanged);
      _pdfTextSearcher?.dispose();
      _pdfTextSearcher = null;

      setState(() {
        _filePath = widget.sharedFile!.path;
        _fileName = widget.sharedFile!.name;
        _currentPageNotifier.value = 1;
        _totalPagesNotifier.value = 0;
        _showOverlays = true;
        _outline = null;
        _isSearchingText = false;
        _searchTextController.clear();
      });
    }
  }

  void _initSearcher() {
    if (_pdfTextSearcher != null) return;
    setState(() {
      _pdfTextSearcher = PdfTextSearcher(_pdfController);
      _pdfTextSearcher!.addListener(_onSearchChanged);
    });
    if (_searchTextController.text.isNotEmpty) {
      _pdfTextSearcher!.startTextSearch(_searchTextController.text);
    }
  }

  void _onSearchChanged() {
    if (mounted && _pdfTextSearcher != null) {
      setState(() {
        _totalMatches = _pdfTextSearcher!.matches.length;
        _currentMatchIndex = _pdfTextSearcher!.currentIndex ?? 0;
      });
    }
  }

  void _onSearchTextChanged() {
    final text = _searchTextController.text;
    _pdfTextSearcher?.startTextSearch(text);
  }

  void _onFileSelected(String path, String name) {
    _pdfTextSearcher?.removeListener(_onSearchChanged);
    _pdfTextSearcher?.dispose();
    _pdfTextSearcher = null;

    setState(() {
      _filePath = path;
      _fileName = name;
      _currentPageNotifier.value = 1;
      _totalPagesNotifier.value = 0;
      _showOverlays = true;
      _outline = null;
      _isSearchingText = false;
      _searchTextController.clear();
    });
  }

  Future<void> _shareFile() async {
    if (_filePath == null) return;
    try {
      await FileSaveHelper.shareFile(_filePath!, 'application/pdf');
    } catch (e) {
      debugPrint('[PdfViewerPage] Share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share file: $e')));
      }
    }
  }

  Future<void> _downloadFile() async {
    if (_filePath == null) return;
    try {
      final bytes = await File(_filePath!).readAsBytes();
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: _fileName ?? 'document.pdf',
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('[PdfViewerPage] Download failed: $e');
    }
  }

  Future<void> _loadOutline() async {
    if (_outline != null || _isLoadingOutline) return;
    setState(() {
      _isLoadingOutline = true;
    });
    try {
      final outline = await _pdfController.document.loadOutline();
      setState(() {
        _outline = outline;
        _isLoadingOutline = false;
      });
    } catch (e) {
      debugPrint('[PdfViewerPage] Failed to load outline: $e');
      setState(() {
        _isLoadingOutline = false;
      });
    }
  }

  PdfPageLayout _horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height =
        pages.fold(
          0.0,
          (prev, page) => prev > page.height ? prev : page.height,
        ) +
        params.margin * 2;
    final pageLayouts = <Rect>[];
    double x = params.margin;
    for (final page in pages) {
      pageLayouts.add(
        Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
      );
      x += page.width + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(x, height),
    );
  }

  PdfPageLayout _doublePageLayout(List<PdfPage> pages, PdfViewerParams params) {
    final pageLayouts = <Rect>[];
    double y = params.margin;
    double maxWidth = 0;
    for (int i = 0; i < pages.length; i += 2) {
      final page1 = pages[i];
      final hasSecond = i + 1 < pages.length;
      final page2 = hasSecond ? pages[i + 1] : null;
      final rowHeight = page2 == null
          ? page1.height
          : math.max(page1.height, page2.height);
      final rowWidth = page1.width + (page2?.width ?? 0.0) + params.margin;
      maxWidth = math.max(maxWidth, rowWidth);
      pageLayouts.add(
        Rect.fromLTWH(
          params.margin,
          y + (rowHeight - page1.height) / 2,
          page1.width,
          page1.height,
        ),
      );
      if (page2 != null) {
        pageLayouts.add(
          Rect.fromLTWH(
            params.margin + page1.width + params.margin,
            y + (rowHeight - page2.height) / 2,
            page2.width,
            page2.height,
          ),
        );
      }
      y += rowHeight + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(maxWidth + params.margin * 2, y),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.menu_book,
                  color: theme.colorScheme.primary,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bookmarks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingOutline
                ? const Center(child: CircularProgressIndicator())
                : _outline == null || _outline!.isEmpty
                ? const Center(child: Text('No bookmarks available'))
                : ListView.builder(
                    itemCount: _outline!.length,
                    itemBuilder: (context, index) {
                      return _buildOutlineTile(_outline![index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineTile(PdfOutlineNode node, [int depth = 0]) {
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;

    if (hasChildren) {
      return ExpansionTile(
        title: Padding(
          padding: EdgeInsets.only(left: depth * 8.0),
          child: Text(
            node.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: node.children
            .map((child) => _buildOutlineTile(child, depth + 1))
            .toList(),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16.0 + (depth * 8.0), right: 16.0),
      title: Text(node.title, style: theme.textTheme.bodyMedium),
      onTap: () {
        if (node.dest != null) {
          _pdfController.goToDest(node.dest);
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_filePath == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PDF Viewer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: PdfDropZone(onFileSelected: _onFileSelected),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.brightness == Brightness.dark
          ? Colors.black
          : Colors.grey[200],
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: PdfDisplay(
              filePath: _filePath!,
              controller: _pdfController,
              boundaryMargin: EdgeInsets.only(
                top: _showOverlays
                    ? MediaQuery.of(context).padding.top + 72
                    : MediaQuery.of(context).padding.top,
                bottom: _showOverlays
                    ? MediaQuery.of(context).padding.bottom + 56
                    : MediaQuery.of(context).padding.bottom,
              ),
              pagePaintCallbacks: [
                if (_pdfTextSearcher != null)
                  _pdfTextSearcher!.pageTextMatchPaintCallback,
              ],
              layoutPages: _layoutMode == PdfLayoutMode.horizontal
                  ? _horizontalLayout
                  : _layoutMode == PdfLayoutMode.doublePage
                  ? _doublePageLayout
                  : null,
              onViewerReady: (doc, controller) {
                _initSearcher();
                final headerHeight = MediaQuery.of(context).padding.top + 72;
                controller.goToPosition(
                  documentOffset: Offset(
                    0,
                    -headerHeight / controller.currentZoom,
                  ),
                );
              },
              onPageChanged: (pageNumber) {
                _currentPageNotifier.value = pageNumber ?? 1;
                _totalPagesNotifier.value = _pdfController.pageCount;
                final page = pageNumber ?? 1;
                if (page > 1 && _showOverlays) {
                  setState(() => _showOverlays = false);
                } else if (page == 1 && !_showOverlays) {
                  setState(() => _showOverlays = true);
                }
              },
              onViewerTap: () {
                setState(() {
                  _showOverlays = !_showOverlays;
                });
              },
            ),
          ),
          Positioned.fill(
            child: PdfOverlayControls(
              fileName: _fileName ?? 'Document',
              controller: _pdfController,
              currentPageNotifier: _currentPageNotifier,
              totalPagesNotifier: _totalPagesNotifier,
              visible: _showOverlays,
              onBack: () {
                setState(() {
                  _filePath = null;
                  _fileName = null;
                });
              },
              onShare: _shareFile,
              onDownload: _downloadFile,
              onOpenBookmarks: () {
                _loadOutline();
                _scaffoldKey.currentState?.openDrawer();
              },
              isSearchingText: _isSearchingText,
              searchTextController: _searchTextController,
              onToggleSearch: () {
                setState(() {
                  _isSearchingText = !_isSearchingText;
                  if (!_isSearchingText) {
                    _searchTextController.clear();
                    _pdfTextSearcher?.resetTextSearch();
                  }
                });
              },
              onPrevMatch: () => _pdfTextSearcher?.goToPrevMatch(),
              onNextMatch: () => _pdfTextSearcher?.goToNextMatch(),
              currentMatchIndex: _currentMatchIndex,
              totalMatches: _totalMatches,
              currentLayoutMode: _layoutMode,
              onLayoutModeChanged: (mode) {
                setState(() {
                  _layoutMode = mode;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

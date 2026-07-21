import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_page_layouts.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/document_password_dialog.dart';
import 'package:tool_lab/tools/pdf_viewer/config.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_display.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_overlay_controls.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_drawer.dart';
import 'package:tool_lab/tools/pdf_viewer/layout_mode.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_viewer_mode.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_organize_panel.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_flatten_panel.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_images_panel.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_extract_text_panel.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_metadata_panel.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_sign_panel.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_redact_panel.dart';
import 'package:file_selector/file_selector.dart' show XFile;

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
  bool _suppressAutoHide = false;
  bool _userToggledOverlays = false;

  List<PdfOutlineNode>? _outline;
  bool _isLoadingOutline = false;

  PdfTextSearcher? _pdfTextSearcher;
  bool _isSearchingText = false;
  final TextEditingController _searchTextController = TextEditingController();
  int _currentMatchIndex = 0;
  int _totalMatches = 0;

  PdfLayoutMode _layoutMode = PdfLayoutMode.vertical;

  PdfViewerMode _mode = PdfViewerMode.view;
  late final TempFileScope _tempScope;
  PdfTextSelection? _currentTextSelection;
  String? _resolvedPdfPassword;
  String? _lastProvidedPdfPassword;
  Future<String?>? _passwordDialogFuture;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();

    _searchTextController.addListener(_onSearchTextChanged);
    _tempScope = TempFileManager.createScope();

    onDispose(() {
      _pdfTextSearcher?.removeListener(_onSearchChanged);
      _pdfTextSearcher?.dispose();
      _searchTextController.dispose();
      _currentPageNotifier.dispose();
      _totalPagesNotifier.dispose();
      _tempScope.cleanTracked();
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
      _resetViewerState(notify: false);
      setState(() {
        _filePath = widget.sharedFile!.path;
        _fileName = widget.sharedFile!.name;
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

  void _resetViewerState({bool notify = true}) {
    _pdfTextSearcher?.removeListener(_onSearchChanged);
    _pdfTextSearcher?.dispose();
    _pdfTextSearcher = null;
    _resolvedPdfPassword = null;
    _lastProvidedPdfPassword = null;
    _passwordDialogFuture = null;

    void applyReset() {
      _currentPageNotifier.value = 1;
      _totalPagesNotifier.value = 0;
      _showOverlays = true;
      _userToggledOverlays = false;
      _outline = null;
      _isSearchingText = false;
      _searchTextController.clear();
      _currentTextSelection = null;
    }

    if (notify) {
      setState(applyReset);
      return;
    }
    applyReset();
  }

  Future<String?> _providePdfPassword() async {
    if (_resolvedPdfPassword != null) {
      return _resolvedPdfPassword;
    }
    if (_passwordDialogFuture != null) {
      return _passwordDialogFuture;
    }

    final l10n = AppLocalizations.of(context);
    final passwordFuture = DocumentPasswordDialog.show(
      context,
      title: l10n.pdfNavPasswordTitle,
      message: l10n.pdfNavPasswordMessage(_fileName ?? 'document.pdf'),
    );
    _passwordDialogFuture = passwordFuture;

    final password = await passwordFuture;
    _passwordDialogFuture = null;
    _lastProvidedPdfPassword = password;
    return password;
  }

  void _handleDocumentLoadError(Object error) {
    if (!mounted) {
      return;
    }

    if (error is PdfPasswordException) {
      _resolvedPdfPassword = null;
      _lastProvidedPdfPassword = null;
      _passwordDialogFuture = null;

      final message = error.message;
      final canceledByUser = message.contains(
        'No password supplied by PasswordProvider',
      );
      if (canceledByUser) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pdfNavOpenCanceled)));
        setState(() {
          _mode = PdfViewerMode.view;
          _filePath = null;
          _fileName = null;
        });
      }
    }
  }

  void _handleDocumentLoadFinished(PdfDocumentRef documentRef, bool succeeded) {
    if (!mounted) {
      return;
    }
    final listenable = documentRef.resolveListenable();
    final error = listenable.error;
    if (error != null) {
      _handleDocumentLoadError(error);
      return;
    }
    if (succeeded && _lastProvidedPdfPassword != null) {
      _resolvedPdfPassword = _lastProvidedPdfPassword;
    }
  }

  void _onFileSelected(XFile file) {
    _resetViewerState();
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
    });
  }

  void _onPrevPage() {
    final page = _currentPageNotifier.value;
    if (page > 1) {
      _suppressAutoHide = true;
      _pdfController.goToPage(pageNumber: page - 1);
    }
  }

  void _onNextPage() {
    final page = _currentPageNotifier.value;
    if (page < _pdfController.pageCount) {
      _suppressAutoHide = true;
      _pdfController.goToPage(pageNumber: page + 1);
    }
  }

  Future<void> _shareFile() async {
    if (_filePath == null) return;
    try {
      if (mounted) {
        await FileSaveHelper.showShareChooser(
          context: context,
          path: _filePath!,
          mimeType: 'application/pdf',
        );
      }
    } catch (e) {
      debugPrint('[PdfViewerPage] Share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).pdfViewerShareFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadFile() async {
    if (_filePath == null) return;
    try {
      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: _fileName ?? 'document.pdf',
        sourcePath: _filePath!,
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

  void _setMode(PdfViewerMode mode) {
    setState(() => _mode = mode);
  }

  void _onSignComplete(String pdfPath, String name) {
    _resetViewerState();
    setState(() {
      _mode = PdfViewerMode.view;
      _filePath = pdfPath;
      _fileName = name;
    });
  }

  void _onSignCancel() {
    setState(() => _mode = PdfViewerMode.view);
  }

  void _onOrganizeComplete(String pdfPath, String name) {
    _resetViewerState();
    setState(() {
      _mode = PdfViewerMode.view;
      _filePath = pdfPath;
      _fileName = name;
    });
  }

  Future<void> _onOrganizeCancel() async {
    setState(() => _mode = PdfViewerMode.view);
  }

  void _onFlattenComplete(String pdfPath, String name) {
    _resetViewerState();
    setState(() {
      _mode = PdfViewerMode.view;
      _filePath = pdfPath;
      _fileName = name;
    });
  }

  void _onFlattenCancel() {
    setState(() => _mode = PdfViewerMode.view);
  }

  void _onExtractImagesCancel() {
    setState(() => _mode = PdfViewerMode.view);
  }

  void _onExtractTextCancel() {
    setState(() => _mode = PdfViewerMode.view);
  }

  void _onMetadataComplete(String pdfPath, String name) {
    _resetViewerState();
    setState(() {
      _mode = PdfViewerMode.view;
      _filePath = pdfPath;
      _fileName = name;
    });
  }

  void _onMetadataCancel() {
    setState(() => _mode = PdfViewerMode.view);
  }

  void _onRedactComplete(String pdfPath, String name) {
    _resetViewerState();
    setState(() {
      _mode = PdfViewerMode.view;
      _filePath = pdfPath;
      _fileName = name;
    });
  }

  void _onRedactCancel() {
    setState(() => _mode = PdfViewerMode.view);
  }

  PdfOperationSession get _operationSession {
    return PdfOperationSession(
      filePath: _filePath!,
      fileName: _fileName ?? 'document.pdf',
      tempScope: _tempScope,
      passwordProvider: _providePdfPassword,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_filePath == null) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        child: FileDropZone(
          onFileSelected: _onFileSelected,
          allowedExtensions: PdfViewerTool.config.fileExtensions,
          allowedMimeTypes: const ['application/pdf'],
          typeLabel: l10n.pdfNavTypeLabel,
          accentColor: PdfViewerTool.config.accentColor,
          icon: Icons.picture_as_pdf_outlined,
          title: l10n.pdfNavDropZoneTitle,
          subtitle: l10n.pdfNavDropZoneSubtitle,
        ),
      );
    }

    if (_mode == PdfViewerMode.sign) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfSignPanel(
          session: _operationSession,
          onComplete: _onSignComplete,
          onCancel: _onSignCancel,
        ),
      );
    }

    if (_mode == PdfViewerMode.organize) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfOrganizePanel(
          session: _operationSession,
          onComplete: _onOrganizeComplete,
          onCancel: _onOrganizeCancel,
        ),
      );
    }

    if (_mode == PdfViewerMode.flatten) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfFlattenPanel(
          session: _operationSession,
          onComplete: _onFlattenComplete,
          onCancel: _onFlattenCancel,
        ),
      );
    }

    if (_mode == PdfViewerMode.extractImages) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfExtractImagesPanel(
          session: _operationSession,
          onCancel: _onExtractImagesCancel,
        ),
      );
    }

    if (_mode == PdfViewerMode.extractText) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfExtractTextPanel(
          session: _operationSession,
          onCancel: _onExtractTextCancel,
        ),
      );
    }

    if (_mode == PdfViewerMode.metadata) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfMetadataPanel(
          session: _operationSession,
          onComplete: _onMetadataComplete,
          onCancel: _onMetadataCancel,
        ),
      );
    }

    if (_mode == PdfViewerMode.redact) {
      return ToolLayout(
        title: PdfViewerTool.config.localizedName(l10n),
        fullscreen: true,
        showFloatingBackButton: false,
        scaffoldKey: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        child: PdfRedactPanel(
          session: _operationSession,
          initialTextSelection: _currentTextSelection,
          onComplete: _onRedactComplete,
          onCancel: _onRedactCancel,
        ),
      );
    }

    return ToolLayout(
      title: PdfViewerTool.config.localizedName(l10n),
      fullscreen: true,
      showFloatingBackButton: false,
      scaffoldKey: _scaffoldKey,
      drawer: PdfDrawer(
        outline: _outline,
        isLoadingOutline: _isLoadingOutline,
        controller: _pdfController,
      ),
      backgroundColor: theme.brightness == Brightness.dark
          ? Colors.black
          : Colors.grey[200],
      child: Stack(
        children: [
          Positioned.fill(
            child: PdfDisplay(
              key: ValueKey(_filePath),
              filePath: _filePath!,
              controller: _pdfController,
              passwordProvider: _providePdfPassword,
              onTextSelectionChange: (selection) {
                _currentTextSelection = selection;
              },
              onDocumentLoadFinished: _handleDocumentLoadFinished,
              boundaryMargin: EdgeInsets.only(
                top: _showOverlays
                    ? MediaQuery.of(context).padding.top + 72
                    : MediaQuery.of(context).padding.top,
                bottom: _showOverlays
                    ? MediaQuery.of(context).padding.bottom + 40
                    : MediaQuery.of(context).padding.bottom,
              ),
              pagePaintCallbacks: [
                if (_pdfTextSearcher != null)
                  _pdfTextSearcher!.pageTextMatchPaintCallback,
              ],
              layoutPages: _layoutMode == PdfLayoutMode.horizontal
                  ? PdfPageLayouts.horizontal
                  : _layoutMode == PdfLayoutMode.doublePage
                  ? PdfPageLayouts.doublePage
                  : null,
              onViewerReady: (doc, controller) {
                _initSearcher();
                _totalPagesNotifier.value = _pdfController.pageCount;
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
                if (_suppressAutoHide || _userToggledOverlays) {
                  _suppressAutoHide = false;
                  return;
                }
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
                  _userToggledOverlays = true;
                });
              },
            ),
          ),
          Positioned.fill(
            child: PdfOverlayControls(
              fileName: _fileName ?? l10n.pdfNavDocumentFallback,
              controller: _pdfController,
              currentPageNotifier: _currentPageNotifier,
              totalPagesNotifier: _totalPagesNotifier,
              visible: _showOverlays,
              currentMode: _mode,
              onModeChanged: _setMode,
              onBack: () {
                if (widget.sharedFile != null) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _filePath = null;
                      _fileName = null;
                    });
                  }
                } else {
                  setState(() {
                    _filePath = null;
                    _fileName = null;
                  });
                }
              },
              onShare: _shareFile,
              onDownload: _downloadFile,
              onPrevPage: _onPrevPage,
              onNextPage: _onNextPage,
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

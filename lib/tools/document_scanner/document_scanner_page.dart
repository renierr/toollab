import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'package:tool_lab/tools/document_scanner/config.dart';
import 'package:tool_lab/tools/document_scanner/document_scanner_state.dart';
import 'package:tool_lab/tools/document_scanner/widgets/crop_editor.dart';
import 'package:tool_lab/tools/document_scanner/widgets/scanned_pages_grid.dart';
import 'package:tool_lab/tools/document_scanner/widgets/page_editor.dart';
import 'package:tool_lab/tools/document_scanner/widgets/scanner_toolbar.dart';

enum ScannerViewMode { list, crop, editPage }

class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({super.key});

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage>
    with DisposeCleanup {
  ScannerViewMode _viewMode = ScannerViewMode.list;
  int _selectedPageIndex = 0;

  late final TempFileScope _pageTempScope;

  @override
  void initState() {
    super.initState();
    _pageTempScope = TempFileManager.createScope();
    onDispose(() => _pageTempScope.cleanTracked());
  }

  Future<void> _captureFromCamera(DocumentScannerState state) async {
    final l10n = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (pickedFile != null) {
        await state.addPage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.docScanFailedCamera(e.toString()))),
        );
      }
    }
  }

  Future<void> _captureFromMlKit(DocumentScannerState state) async {
    final l10n = AppLocalizations.of(context);

    // Retry once on a real failure: on freshly sideloaded builds the Play
    // Services scanner module can still be downloading on the first call.
    for (var attempt = 0; attempt < 2; attempt++) {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {DocumentFormat.jpeg},
          mode: ScannerMode.full,
          isGalleryImport: false,
        ),
      );
      try {
        final result = await documentScanner.scanDocument();
        final images = result.images;
        if (images != null && images.isNotEmpty) {
          for (final path in images) {
            await state.addPage(path, isPreCropped: true);
          }
        }
        return;
      } on PlatformException catch (e) {
        // The plugin reports a user cancellation as an error with this exact
        // message — treat it as a silent cancel, never retry or fall back.
        if (e.message == 'Operation cancelled') {
          debugPrint('[DocumentScanner] Scan cancelled by user');
          return;
        }
        // Otherwise the scanner module is unavailable (still downloading / no
        // Play Services). Retry once, then fall back to the standard camera.
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        debugPrint('[DocumentScanner] ML Kit unavailable, falling back: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.docScanMlKitUnavailableFallback)),
        );
        await _captureFromCamera(state);
        return;
      } catch (e) {
        debugPrint('[DocumentScanner] Scan failed or empty: $e');
        return;
      } finally {
        documentScanner.close();
      }
    }
  }

  Future<void> _onScanPressed(DocumentScannerState state) async {
    final l10n = AppLocalizations.of(context);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (!isAndroid) {
      await _captureFromCamera(state);
      return;
    }

    if (!mounted) return;
    final selection = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.docScanMethodTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(l10n.docScanActionScanMlKit),
                onTap: () => Navigator.of(context).pop('mlkit'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.docScanActionScanStandard),
                onTap: () => Navigator.of(context).pop('standard'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selection == 'mlkit') {
      await _captureFromMlKit(state);
    } else if (selection == 'standard') {
      await _captureFromCamera(state);
    }
  }

  Future<void> _pickFromGallery(DocumentScannerState state) async {
    final l10n = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (pickedFile != null) {
        await state.addPage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.docScanFailedGallery(e.toString()))),
        );
      }
    }
  }

  Future<void> _compilePdf(DocumentScannerState state) async {
    final pages = state.pages;
    if (pages.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    // Temp set state in progress
    // Wait, the state doesn't have a direct setter, but has helper _setProcessing.
    // However, since we compile inside the state, let's write a method in state or do it here.
    // Wait, let's compile here and use a local processing state if we want, or do it inside the state.
    // Let's do it here with local state overlay or a dialog. Since the state already has isProcessing,
    // we can use standard showing of overlay/progress in the coordinator page.
    setState(
      () {},
    ); // trigger rebuild to show indicator if we want, or show a loading indicator dialog.

    // We show a loading dialog for compilation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(l10n.docScanGeneratingPdf)),
            ],
          ),
        ),
      ),
    );

    try {
      final pdfBytes = await PdfEngineHelper.createPdfFromImagePaths(
        pages.map((p) => p.processedImagePath).toList(),
        pageSize: ImageToPdfPageSize.fit,
        jpegQuality: 85,
        landscape: false,
      );

      final pdfPath = await _pageTempScope.createFile(
        'scanned_document_export.pdf',
        bytes: pdfBytes,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: 'scanned_document.pdf',
        sourcePath: pdfPath,
        successMessageGeneralBuilder: (path) => l10n.docScanSavedPdf(path),
        errorMessageBuilder: (e) => l10n.docScanFailedPdf(e.toString()),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        FileSaveHelper.showErrorNotification(
          context: context,
          errorMessage: l10n.docScanFailedCreate(e.toString()),
        );
      }
    }
  }

  Future<void> _clearAll(DocumentScannerState state) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.docScanClearTitle),
        content: Text(l10n.docScanClearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.docScanClearConfirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await state.clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DocumentScannerState>();
    final accentColor = DocumentScannerTool.config.accentColor;

    // 1. If we are in crop editor mode
    if (_viewMode == ScannerViewMode.crop) {
      final page = state.pages[_selectedPageIndex];
      return CropEditor(
        originalImagePath: page.originalImagePath,
        initialCorners: page.corners,
        accentColor: accentColor,
        onCancel: () {
          setState(() {
            _viewMode = ScannerViewMode.editPage;
          });
        },
        onApply: (newCorners) async {
          setState(() {
            _viewMode = ScannerViewMode.editPage;
          });
          await state.updatePageCrop(_selectedPageIndex, newCorners);
        },
      );
    }

    // 2. If we are in page editor mode
    if (_viewMode == ScannerViewMode.editPage) {
      final page = state.pages[_selectedPageIndex];
      return PageEditor(
        page: page,
        pageIndex: _selectedPageIndex,
        accentColor: accentColor,
        onBack: () {
          setState(() {
            _viewMode = ScannerViewMode.list;
          });
        },
        onAdjustCrop: () {
          setState(() {
            _viewMode = ScannerViewMode.crop;
          });
        },
        onFilterChanged: (filter) async {
          await state.updatePageFilter(_selectedPageIndex, filter);
        },
        onRotate: (angle) async {
          await state.rotatePage(_selectedPageIndex, angle);
        },
      );
    }

    // 3. Default List View mode
    return ToolLayout(
      title: DocumentScannerTool.config.localizedName(l10n),
      child: Column(
        children: [
          // Loading Indicator overlay if state is processing
          if (state.isProcessing)
            Container(
              color: accentColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.progressText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main Pages List
          Expanded(
            child: ScannedPagesList(
              onEditPage: (index) {
                setState(() {
                  _selectedPageIndex = index;
                  _viewMode = ScannerViewMode.editPage;
                });
              },
              onDeletePage: (index) async {
                await state.removePage(index);
              },
              onReorder: (oldIdx, newIdx) {
                state.reorderPages(oldIdx, newIdx);
              },
            ),
          ),

          // Bottom Actions Toolbar
          ScannerToolbar(
            hasPages: state.pages.isNotEmpty,
            isProcessing: state.isProcessing,
            accentColor: accentColor,
            onAddCamera: () => _onScanPressed(state),
            onAddGallery: () => _pickFromGallery(state),
            onCompilePdf: () => _compilePdf(state),
            onClearAll: () => _clearAll(state),
          ),
        ],
      ),
    );
  }
}

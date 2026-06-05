import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_drop_zone.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_display.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_overlay_controls.dart';

class PdfViewerPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const PdfViewerPage({super.key, this.sharedFile});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> with DisposeCleanup {
  late final PdfViewerController _pdfController;
  String? _filePath;
  String? _fileName;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showOverlays = true;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();

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
      setState(() {
        _filePath = widget.sharedFile!.path;
        _fileName = widget.sharedFile!.name;
        _currentPage = 1;
        _totalPages = 0;
        _showOverlays = true;
      });
    }
  }

  void _onFileSelected(String path, String name) {
    setState(() {
      _filePath = path;
      _fileName = name;
      _currentPage = 1;
      _totalPages = 0;
      _showOverlays = true;
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
      backgroundColor: theme.brightness == Brightness.dark
          ? Colors.black
          : Colors.grey[200],
      body: Stack(
        children: [
          Positioned.fill(
            child: PdfDisplay(
              filePath: _filePath!,
              controller: _pdfController,
              boundaryMargin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 76,
                bottom: MediaQuery.of(context).padding.bottom + 84,
              ),
              onPageChanged: (pageNumber) {
                setState(() {
                  _currentPage = pageNumber ?? 1;
                  _totalPages = _pdfController.pageCount;
                });
              },
              onViewerTap: () {
                setState(() {
                  _showOverlays = !_showOverlays;
                });
              },
            ),
          ),

          // Header/Footer Overlay controls
          Positioned.fill(
            child: PdfOverlayControls(
              fileName: _fileName ?? 'Document',
              controller: _pdfController,
              currentPage: _currentPage,
              totalPages: _totalPages > 0 ? _totalPages : 1,
              visible: _showOverlays,
              onBack: () {
                setState(() {
                  _filePath = null;
                  _fileName = null;
                });
              },
              onShare: _shareFile,
              onDownload: _downloadFile,
            ),
          ),
        ],
      ),
    );
  }
}

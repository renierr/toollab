import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_metadata_view.dart';
import 'package:tool_lab/tools/pdf_viewer/widgets/pdf_result_view.dart';

class PdfMetadataPanel extends StatefulWidget {
  final PdfOperationSession session;
  final void Function(String pdfPath, String name) onComplete;
  final VoidCallback onCancel;

  const PdfMetadataPanel({
    super.key,
    required this.session,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<PdfMetadataPanel> createState() => _PdfMetadataPanelState();
}

enum _MetadataPhase { loading, viewing, processing, done }

class _PdfMetadataPanelState extends State<PdfMetadataPanel> {
  _MetadataPhase _phase = _MetadataPhase.loading;
  String? _errorText;
  String? _resultPath;
  int _resultSize = 0;

  bool _isEncrypted = false;
  int? _permissionsRaw;
  int? _securityRevision;
  PdfDocumentMetadata? _metadata;

  String get _baseName => widget.session.fileName.replaceAll('.pdf', '');

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _phase = _MetadataPhase.loading;
      _errorText = null;
    });

    PdfDocument? doc;
    try {
      doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
      final metadata = await PdfEngineHelper.readMetadata(
        doc,
        widget.session.filePath,
      ).timeout(const Duration(seconds: 60));
      final permissions = doc.permissions;

      if (!mounted) {
        return;
      }

      setState(() {
        _metadata = metadata;
        _isEncrypted = doc!.isEncrypted;
        _permissionsRaw = permissions?.permissions;
        _securityRevision = permissions?.securityHandlerRevision;
        _phase = _MetadataPhase.viewing;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _phase = _MetadataPhase.viewing;
        _errorText = l10n.pdfEditMetaLoadError(e.toString());
      });
    } finally {
      await doc?.dispose();
    }
  }

  Future<void> _decryptAndSave() async {
    setState(() {
      _phase = _MetadataPhase.processing;
      _errorText = null;
    });

    PdfDocument? doc;
    try {
      doc = await widget.session.openDocument().timeout(
        const Duration(seconds: 30),
      );
      final bytes = await PdfEngineHelper.createUnsecuredCopy(
        doc,
      ).timeout(const Duration(minutes: 5));

      final outName = '${_baseName}_unsecured.pdf';
      final resultPath = await widget.session.tempScope.createFile(
        outName,
        bytes: bytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resultPath = resultPath;
        _resultSize = bytes.length;
        _phase = _MetadataPhase.done;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _phase = _MetadataPhase.viewing;
        _errorText = l10n.pdfEditMetaRemoveSecurityError(e.toString());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pdfEditMetaSaveFailed(e.toString()))),
      );
    } finally {
      await doc?.dispose();
    }
  }

  Future<void> _download() async {
    final path = _resultPath;
    if (path == null) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: '${_baseName}_unsecured.pdf',
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
        title: Text(l10n.pdfEditMetaTitle2(widget.session.fileName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.pdfEditMetaReload,
            onPressed: _phase == _MetadataPhase.processing
                ? null
                : _loadMetadata,
          ),
        ],
      ),
      body: switch (_phase) {
        _MetadataPhase.loading || _MetadataPhase.processing => const Center(
          child: CircularProgressIndicator(),
        ),
        _MetadataPhase.viewing => PdfMetadataView(
          metadata: _metadata,
          fileName: widget.session.fileName,
          errorText: _errorText,
          isEncrypted: _isEncrypted,
          permissionsRaw: _permissionsRaw,
          securityRevision: _securityRevision,
          onRemovePassword: _decryptAndSave,
        ),
        _MetadataPhase.done => PdfResultView(
          title: l10n.pdfEditMetaDoneTitle,
          subtitle: l10n.pdfEditFlattenDoneSize(
            formatFileSize(_resultSize, l10n.pdfEditMetaUnknown),
          ),
          onDownload: _download,
          onShare: _share,
          onOpenInViewer: () =>
              widget.onComplete(_resultPath!, '${_baseName}_unsecured.pdf'),
          onClose: widget.onCancel,
        ),
      },
    );
  }
}

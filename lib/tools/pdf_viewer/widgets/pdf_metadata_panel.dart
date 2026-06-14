import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/tools/pdf_viewer/pdf_operation_session.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/info_card.dart';

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
      doc = await widget.session.openDocument();
      final metadata = await PdfEngineHelper.readMetadata(
        doc,
        widget.session.filePath,
      );
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
      setState(() {
        _phase = _MetadataPhase.viewing;
        _errorText = 'Failed to load metadata: $e';
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
      doc = await widget.session.openDocument();
      final bytes = await PdfEngineHelper.createUnsecuredCopy(doc);

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
      setState(() {
        _phase = _MetadataPhase.viewing;
        _errorText = 'Failed to remove security: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
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

  bool _isPermissionAllowed(int bitMask) {
    if (!_isEncrypted) return true;
    if (_permissionsRaw == null) return true;
    return (_permissionsRaw! & bitMask) != 0;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatPageSize(double width, double height) {
    if (width == 0 || height == 0) return 'Unknown';
    final widthInches = width / 72.0;
    final heightInches = height / 72.0;
    final widthMm = widthInches * 25.4;
    final heightMm = heightInches * 25.4;

    String formatName = '';
    if ((width - 595).abs() < 3 && (height - 842).abs() < 3) {
      formatName = ' (A4)';
    } else if ((width - 842).abs() < 3 && (width - 595).abs() < 3) {
      formatName = ' (A4 Landscape)';
    } else if ((width - 612).abs() < 3 && (height - 792).abs() < 3) {
      formatName = ' (Letter)';
    } else if ((width - 792).abs() < 3 && (height - 612).abs() < 3) {
      formatName = ' (Letter Landscape)';
    } else if ((width - 612).abs() < 3 && (height - 1008).abs() < 3) {
      formatName = ' (Legal)';
    }

    return '${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} pt'
        ' / ${widthInches.toStringAsFixed(2)} × ${heightInches.toStringAsFixed(2)} in'
        ' (${widthMm.toStringAsFixed(0)} × ${heightMm.toStringAsFixed(0)} mm)$formatName';
  }

  Widget _buildPermissionRow(BuildContext context, String label, bool allowed) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle_outline : Icons.block_outlined,
            color: allowed ? AppTheme.statusGreen : AppTheme.statusRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            allowed ? 'Allowed' : 'Restricted',
            style: theme.textTheme.bodySmall?.copyWith(
              color: allowed ? AppTheme.statusGreen : AppTheme.statusRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewing(ThemeData theme) {
    if (_metadata == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorText ?? 'Failed to load metadata',
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final metadata = _metadata!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorText!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        InfoCard(
          icon: Icons.info_outline,
          title: 'Document Specifications',
          child: Column(
            children: [
              InfoRow(label: 'File Name', value: widget.session.fileName),
              const Divider(height: 16),
              InfoRow(
                label: 'File Size',
                value: _formatFileSize(metadata.fileSize),
              ),
              const Divider(height: 16),
              InfoRow(
                label: 'Page Count',
                value: metadata.pageCount.toString(),
              ),
              const Divider(height: 16),
              InfoRow(
                label: 'PDF Version',
                value: 'PDF ${metadata.pdfVersion}',
              ),
              const Divider(height: 16),
              InfoRow(
                label: 'Page Dimensions',
                value: _formatPageSize(
                  metadata.widthPoints,
                  metadata.heightPoints,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.description_outlined,
          title: 'Document Metadata',
          child: Column(
            children: [
              InfoRow(label: 'Title', value: metadata.title),
              const Divider(height: 16),
              InfoRow(label: 'Author', value: metadata.author),
              const Divider(height: 16),
              InfoRow(label: 'Subject', value: metadata.subject),
              const Divider(height: 16),
              InfoRow(label: 'Keywords', value: metadata.keywords),
              const Divider(height: 16),
              InfoRow(label: 'Creator', value: metadata.creator),
              const Divider(height: 16),
              InfoRow(label: 'Producer', value: metadata.producer),
              const Divider(height: 16),
              InfoRow(label: 'Creation Date', value: metadata.creationDate),
              const Divider(height: 16),
              InfoRow(
                label: 'Modification Date',
                value: metadata.modificationDate,
              ),
              const Divider(height: 16),
              InfoRow(label: 'Trapped', value: metadata.trapped),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.security_outlined,
          title: 'Security & Restrictions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                label: 'Encrypted',
                value: _isEncrypted
                    ? 'Yes (Revision ${_securityRevision ?? 'unknown'})'
                    : 'No',
              ),
              const Divider(height: 24),
              Text(
                'Restrictions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildPermissionRow(
                context,
                'Printing (Low Resolution)',
                _isPermissionAllowed(4),
              ),
              _buildPermissionRow(
                context,
                'High-Quality Printing',
                _isPermissionAllowed(2048),
              ),
              _buildPermissionRow(
                context,
                'Modifying Document Content',
                _isPermissionAllowed(8),
              ),
              _buildPermissionRow(
                context,
                'Content Copying & Extraction',
                _isPermissionAllowed(16),
              ),
              _buildPermissionRow(
                context,
                'Adding/Modifying Annotations',
                _isPermissionAllowed(32),
              ),
              _buildPermissionRow(
                context,
                'Filling Interactive Forms',
                _isPermissionAllowed(256),
              ),
              _buildPermissionRow(
                context,
                'Accessibility Extraction',
                _isPermissionAllowed(512),
              ),
              _buildPermissionRow(
                context,
                'Document Assembly',
                _isPermissionAllowed(1024),
              ),
              if (_isEncrypted) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _decryptAndSave,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Remove Password & Save Copy'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDone(ThemeData theme) {
    final size = _resultSize;
    final sizeText = _formatFileSize(size);
    final outName = '${_baseName}_unsecured.pdf';

    return Center(
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
              'Security Removal Complete',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'New PDF size: $sizeText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
                OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => widget.onComplete(_resultPath!, outName),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Viewer'),
            ),
            TextButton(onPressed: widget.onCancel, child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Metadata: ${widget.session.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _phase == _MetadataPhase.processing
              ? null
              : widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload metadata',
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
        _MetadataPhase.viewing => _buildViewing(theme),
        _MetadataPhase.done => _buildDone(theme),
      },
    );
  }
}

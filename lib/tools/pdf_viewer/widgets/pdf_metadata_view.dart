import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/info_card.dart';

/// Read-only report for a loaded PDF: specs, metadata and security flags.
class PdfMetadataView extends StatelessWidget {
  final PdfDocumentMetadata? metadata;
  final String fileName;
  final String? errorText;
  final bool isEncrypted;
  final int? permissionsRaw;
  final int? securityRevision;
  final VoidCallback onRemovePassword;

  const PdfMetadataView({
    super.key,
    required this.metadata,
    required this.fileName,
    required this.errorText,
    required this.isEncrypted,
    required this.permissionsRaw,
    required this.securityRevision,
    required this.onRemovePassword,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (metadata == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            errorText ?? l10n.pdfEditMetaLoadFailed,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final meta = metadata!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              errorText!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        InfoCard(
          icon: Icons.info_outline,
          title: l10n.pdfEditMetaSpecsTitle,
          child: Column(
            children: [
              InfoRow(label: l10n.pdfEditMetaFileName, value: fileName),
              const Divider(height: 16),
              InfoRow(
                label: l10n.pdfEditMetaFileSize,
                value: formatFileSize(meta.fileSize, l10n.pdfEditMetaUnknown),
              ),
              const Divider(height: 16),
              InfoRow(
                label: l10n.pdfEditMetaPageCount,
                value: meta.pageCount.toString(),
              ),
              const Divider(height: 16),
              InfoRow(
                label: l10n.pdfEditMetaPdfVersion,
                value: 'PDF ${meta.pdfVersion}',
              ),
              const Divider(height: 16),
              InfoRow(
                label: l10n.pdfEditMetaPageDimensions,
                value: formatPageSize(
                  meta.widthPoints,
                  meta.heightPoints,
                  l10n.pdfEditMetaUnknown,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.description_outlined,
          title: l10n.pdfEditMetaMetadataTitle,
          child: Column(
            children: [
              InfoRow(label: l10n.pdfEditMetaTitle, value: meta.title),
              const Divider(height: 16),
              InfoRow(label: l10n.pdfEditMetaAuthor, value: meta.author),
              const Divider(height: 16),
              InfoRow(label: l10n.pdfEditMetaSubject, value: meta.subject),
              const Divider(height: 16),
              InfoRow(label: l10n.pdfEditMetaKeywords, value: meta.keywords),
              const Divider(height: 16),
              InfoRow(label: l10n.pdfEditMetaCreator, value: meta.creator),
              const Divider(height: 16),
              InfoRow(label: l10n.pdfEditMetaProducer, value: meta.producer),
              const Divider(height: 16),
              InfoRow(
                label: l10n.pdfEditMetaCreationDate,
                value: meta.creationDate,
              ),
              const Divider(height: 16),
              InfoRow(
                label: l10n.pdfEditMetaModDate,
                value: meta.modificationDate,
              ),
              const Divider(height: 16),
              InfoRow(label: l10n.pdfEditMetaTrapped, value: meta.trapped),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.security_outlined,
          title: l10n.pdfEditMetaSecurityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                label: l10n.pdfEditMetaEncrypted,
                value: isEncrypted
                    ? l10n.pdfEditMetaEncryptedYes(
                        securityRevision?.toString() ?? l10n.pdfEditMetaUnknown,
                      )
                    : l10n.commonNo,
              ),
              const Divider(height: 24),
              Text(
                l10n.pdfEditMetaRestrictions,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _PermissionRow(
                label: l10n.pdfEditMetaPermPrintLow,
                allowed: _isPermissionAllowed(permissionsRaw, isEncrypted, 4),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermPrintHigh,
                allowed: _isPermissionAllowed(
                  permissionsRaw,
                  isEncrypted,
                  2048,
                ),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermModifyContent,
                allowed: _isPermissionAllowed(permissionsRaw, isEncrypted, 8),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermCopyExtract,
                allowed: _isPermissionAllowed(permissionsRaw, isEncrypted, 16),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermAnnotations,
                allowed: _isPermissionAllowed(permissionsRaw, isEncrypted, 32),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermForms,
                allowed: _isPermissionAllowed(permissionsRaw, isEncrypted, 256),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermAccessibility,
                allowed: _isPermissionAllowed(permissionsRaw, isEncrypted, 512),
              ),
              _PermissionRow(
                label: l10n.pdfEditMetaPermAssembly,
                allowed: _isPermissionAllowed(
                  permissionsRaw,
                  isEncrypted,
                  1024,
                ),
              ),
              if (isEncrypted) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRemovePassword,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: Text(l10n.pdfEditMetaRemovePassword),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool allowed;

  const _PermissionRow({required this.label, required this.allowed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
            allowed
                ? l10n.pdfEditMetaPermAllowed
                : l10n.pdfEditMetaPermRestricted,
            style: theme.textTheme.bodySmall?.copyWith(
              color: allowed ? AppTheme.statusGreen : AppTheme.statusRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

String formatFileSize(int bytes, String unknown) {
  if (bytes <= 0) return unknown;
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatPageSize(double width, double height, String unknown) {
  if (width == 0 || height == 0) return unknown;
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

bool _isPermissionAllowed(int? permissionsRaw, bool isEncrypted, int bitMask) {
  if (!isEncrypted) return true;
  if (permissionsRaw == null) return true;
  return (permissionsRaw & bitMask) != 0;
}

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../models/paperless_upload.dart';
import '../paperless_error_text.dart';

class PaperlessUploadTile extends StatelessWidget {
  final PaperlessUpload upload;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const PaperlessUploadTile({
    super.key,
    required this.upload,
    required this.onRename,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = upload.error;

    final status = switch (upload.status) {
      PaperlessUploadStatus.pending => l10n.paperlessUploadStatusPending,
      PaperlessUploadStatus.uploading => l10n.paperlessUploadStatusUploading(
        ((upload.progress ?? 0) * 100).round(),
      ),
      PaperlessUploadStatus.processing => l10n.paperlessUploadStatusProcessing,
      PaperlessUploadStatus.queued => l10n.paperlessUploadStatusQueued,
      PaperlessUploadStatus.done => l10n.paperlessUploadStatusDone,
      PaperlessUploadStatus.failed =>
        error == null ? l10n.commonError : describePaperlessError(l10n, error),
    };

    return ListTile(
      leading: _StatusIcon(upload: upload),
      title: Text(
        upload.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upload.title != null)
            Text(upload.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            status,
            style: upload.status == PaperlessUploadStatus.failed
                ? theme.textTheme.bodySmall?.copyWith(color: AppTheme.statusRed)
                : null,
          ),
          if (upload.status == PaperlessUploadStatus.uploading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: upload.progress),
            ),
        ],
      ),
      trailing: Wrap(
        children: [
          if (upload.status == PaperlessUploadStatus.pending)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.commonRename,
              onPressed: onRename,
            ),
          if (upload.status == PaperlessUploadStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.commonRetry,
              onPressed: onRetry,
            ),
          if (!upload.isActive)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonRemove,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final PaperlessUpload upload;

  const _StatusIcon({required this.upload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: switch (upload.status) {
          PaperlessUploadStatus.pending => Icon(
            Icons.insert_drive_file_outlined,
            color: theme.hintColor,
          ),
          PaperlessUploadStatus.uploading ||
          PaperlessUploadStatus.processing => const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          PaperlessUploadStatus.queued => const Icon(
            Icons.schedule,
            color: AppTheme.statusBlue,
          ),
          PaperlessUploadStatus.done => const Icon(
            Icons.check_circle_outline,
            color: AppTheme.statusGreen,
          ),
          PaperlessUploadStatus.failed => const Icon(
            Icons.error_outline,
            color: AppTheme.statusRed,
          ),
        },
      ),
    );
  }
}

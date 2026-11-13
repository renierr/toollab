import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../models/paperless_upload.dart';
import '../paperless_error_text.dart';
import '../paperless_state.dart';

class PaperlessUploadTile extends StatelessWidget {
  final PaperlessUpload upload;
  final VoidCallback onEdit;
  final VoidCallback onAnalyze;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const PaperlessUploadTile({
    super.key,
    required this.upload,
    required this.onEdit,
    required this.onAnalyze,
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
          if (upload.hasMetadata) _UploadMetadata(upload: upload),
          if (upload.status == PaperlessUploadStatus.pending)
            _AnalysisStatus(analysis: upload.analysis),
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
          if (upload.status == PaperlessUploadStatus.pending) ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: l10n.paperlessAnalyze,
              onPressed: upload.analysis == PaperlessAnalysisStatus.running
                  ? null
                  : onAnalyze,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.paperlessEditUpload,
              onPressed: onEdit,
            ),
          ],
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

class _UploadMetadata extends StatelessWidget {
  final PaperlessUpload upload;

  const _UploadMetadata({required this.upload});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PaperlessState>();
    final created = upload.created;
    final tagNames = [
      for (final id in upload.tagIds ?? const <int>{}) ?state.tag(id)?.name,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          if (created != null)
            _MetaItem(
              icon: Icons.event_outlined,
              text: FormatHelper.dateTime(created, style: DateStyle.dateOnly),
            ),
          if (state.correspondent(upload.correspondentId) case final c?)
            _MetaItem(icon: Icons.person_outline, text: c.name),
          if (state.documentType(upload.documentTypeId) case final t?)
            _MetaItem(icon: Icons.category_outlined, text: t.name),
          if (tagNames.isNotEmpty)
            _MetaItem(icon: Icons.label_outline, text: tagNames.join(', ')),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AnalysisStatus extends StatelessWidget {
  final PaperlessAnalysisStatus analysis;

  const _AnalysisStatus({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    return switch (analysis) {
      PaperlessAnalysisStatus.running => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.paperlessAnalyzing, style: style),
            const SizedBox(height: 4),
            const LinearProgressIndicator(),
          ],
        ),
      ),
      PaperlessAnalysisStatus.empty => Text(
        l10n.paperlessAnalysisEmpty,
        style: style,
      ),
      PaperlessAnalysisStatus.failed => Text(
        l10n.paperlessAnalysisFailed,
        style: style?.copyWith(color: AppTheme.statusAmber),
      ),
      PaperlessAnalysisStatus.none ||
      PaperlessAnalysisStatus.done => const SizedBox.shrink(),
    };
  }
}

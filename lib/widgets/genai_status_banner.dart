import 'dart:io';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:google_mlkit_genai_prompt/src/prompt.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Shared on-device GenAI (Gemini Nano) model-status banner.
///
/// Shows model availability and a download/prepare action. Used by any tool
/// that exposes the on-device AI (chat_ai, pdf_viewer extract-text).
class GenAiStatusBanner extends StatelessWidget {
  final FeatureStatus status;
  final VoidCallback onDownload;

  const GenAiStatusBanner({
    super.key,
    required this.status,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (!Platform.isAndroid) {
      return Container(
        color: theme.colorScheme.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.genaiOfflineAnalysisActive,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (status == FeatureStatus.downloadable ||
              status == FeatureStatus.unavailable)
            TextButton.icon(
              onPressed: onDownload,
              icon: Icon(
                status == FeatureStatus.unavailable
                    ? Icons.settings_suggest_outlined
                    : Icons.download_rounded,
                size: 16,
              ),
              label: Text(
                status == FeatureStatus.unavailable
                    ? l10n.chatAiPrepareButton
                    : l10n.chatAiDownloadButton,
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Color get _statusColor => switch (status) {
    FeatureStatus.available => Colors.green,
    FeatureStatus.downloading => Colors.blue,
    FeatureStatus.downloadable => Colors.orange,
    FeatureStatus.unavailable => Colors.red,
  };

  String _getStatusText(AppLocalizations l10n) {
    switch (status) {
      case FeatureStatus.available:
        return l10n.chatAiModelReady;
      case FeatureStatus.downloading:
        return l10n.chatAiModelLoading;
      case FeatureStatus.downloadable:
        return l10n.chatAiModelNotDownloaded;
      case FeatureStatus.unavailable:
        return l10n.genaiOfflineAnalysisActive;
    }
  }
}

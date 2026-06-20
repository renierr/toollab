import 'dart:io';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:google_mlkit_genai_prompt/src/prompt.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class ChatStatusBanner extends StatelessWidget {
  final FeatureStatus status;
  final VoidCallback onDownload;

  const ChatStatusBanner({
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
        color: AppTheme.statusAmber.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.statusAmber,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.chatAiUnsupportedPlatform,
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
          _buildDot(theme),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (status == FeatureStatus.downloadable)
            TextButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                l10n.chatAiDownloadButton,
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

  Widget _buildDot(ThemeData theme) {
    final Color color;
    switch (status) {
      case FeatureStatus.available:
        color = Colors.green;
        break;
      case FeatureStatus.downloading:
        color = Colors.blue;
        break;
      case FeatureStatus.downloadable:
        color = Colors.orange;
        break;
      case FeatureStatus.unavailable:
        color = Colors.red;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _getStatusText(AppLocalizations l10n) {
    switch (status) {
      case FeatureStatus.available:
        return l10n.chatAiModelReady;
      case FeatureStatus.downloading:
        return l10n.chatAiModelLoading;
      case FeatureStatus.downloadable:
        return l10n.chatAiModelNotDownloaded;
      case FeatureStatus.unavailable:
        return 'AICore / Gemini Nano unavailable (Simulated Chat)';
    }
  }
}

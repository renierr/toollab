import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

class PaperlessUploadToolbar extends StatelessWidget {
  final int pendingCount;
  final bool isConfigured;
  final bool isUploading;
  final bool canClear;
  final VoidCallback onAdd;
  final VoidCallback onClear;
  final VoidCallback onUpload;
  final VoidCallback onOpenSettings;

  const PaperlessUploadToolbar({
    super.key,
    required this.pendingCount,
    required this.isConfigured,
    required this.isUploading,
    required this.canClear,
    required this.onAdd,
    required this.onClear,
    required this.onUpload,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToolChip(icon: Icons.add, label: l10n.commonAdd, onTap: onAdd),
          if (canClear)
            ToolChip(
              icon: Icons.clear_all,
              label: l10n.paperlessUploadClearFinished,
              onTap: onClear,
            ),
          if (!isConfigured)
            ActionChip(
              avatar: const Icon(
                Icons.link_off,
                size: 16,
                color: AppTheme.statusAmber,
              ),
              label: Text(l10n.paperlessUploadNeedsConnection),
              onPressed: onOpenSettings,
            )
          else if (pendingCount > 0 || isUploading)
            FilledButton.icon(
              onPressed: isUploading ? null : onUpload,
              icon: isUploading
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurface,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                isUploading
                    ? l10n.paperlessUploading
                    : l10n.paperlessUploadCount(pendingCount),
              ),
            ),
        ],
      ),
    );
  }
}

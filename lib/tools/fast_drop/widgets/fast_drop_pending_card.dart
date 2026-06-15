import 'package:flutter/material.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/theme/theme.dart';

class FastDropPendingCard extends StatelessWidget {
  final List<SharedFile> files;
  final bool isUploading;
  final bool isActionsEnabled;
  final VoidCallback onUpload;
  final VoidCallback onDismiss;

  const FastDropPendingCard({
    super.key,
    required this.files,
    required this.isUploading,
    required this.isActionsEnabled,
    required this.onUpload,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (files.isEmpty) return const SizedBox.shrink();

    final titleText = files.length == 1
        ? 'Shared File Received'
        : 'Shared Files Received';

    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.share_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titleText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (files.length == 1)
              Text(
                files.first.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${files.length} files shared:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...files
                      .take(3)
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                          child: Text(
                            '• ${f.name}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  if (files.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                      child: Text(
                        'and ${files.length - 3} more...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            if (isUploading)
              const LinearProgressIndicator(color: AppTheme.accentTeal)
            else
              FilledButton.icon(
                onPressed: isActionsEnabled ? onUpload : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  files.length == 1
                      ? 'Upload to Server'
                      : 'Upload All to Server',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

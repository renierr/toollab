import 'package:flutter/material.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/theme/theme.dart';

class FastDropPendingCard extends StatelessWidget {
  final SharedFile file;
  final bool isUploading;
  final bool isActionsEnabled;
  final VoidCallback onUpload;
  final VoidCallback onDismiss;

  const FastDropPendingCard({
    super.key,
    required this.file,
    required this.isUploading,
    required this.isActionsEnabled,
    required this.onUpload,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    'Shared File Received',
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
            Text(
              file.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (isUploading)
              const LinearProgressIndicator(color: AppTheme.accentTeal)
            else
              FilledButton.icon(
                onPressed: isActionsEnabled ? onUpload : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload to Server'),
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

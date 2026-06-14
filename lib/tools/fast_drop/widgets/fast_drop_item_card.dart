import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import '../fast_drop_model.dart';

class FastDropItemCard extends StatelessWidget {
  final FastDropItem item;
  final VoidCallback onDelete;
  final VoidCallback onPreview;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onEditDescription;
  final VoidCallback onEditRetention;

  const FastDropItemCard({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onPreview,
    required this.onOpen,
    required this.onDownload,
    required this.onEditDescription,
    required this.onEditRetention,
  });

  IconData _getFileIcon(String type) {
    final mime = type.toLowerCase();
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('javascript') ||
        mime.contains('xml')) {
      return Icons.article_outlined;
    }
    if (mime.contains('zip') ||
        mime.contains('archive') ||
        mime.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedType = item.type == 'application/octet-stream'
        ? MimeTypeHelper.getMimeType(item.filename)
        : item.type;
    final sizeText = FormatHelper.fileSize(item.size);
    final icon = _getFileIcon(resolvedType);
    final isExpires = item.expiresAt != null;
    final expiresText = isExpires
        ? 'Expires: ${FormatHelper.dateTime(item.expiresAt!)}'
        : 'Indefinite retention';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.filename,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.source == 'clipboard')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.paste_outlined,
                          size: 10,
                          color: AppTheme.accentTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CLIPBOARD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24, color: AppTheme.accentTeal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            sizeText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            '•',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            resolvedType,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: onEditRetention,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                expiresText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: isExpires
                                      ? AppTheme.statusOrange
                                      : AppTheme.statusGreen,
                                  fontWeight: isExpires
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 10,
                                color: isExpires
                                    ? AppTheme.statusOrange.withValues(
                                        alpha: 0.8,
                                      )
                                    : AppTheme.statusGreen.withValues(
                                        alpha: 0.8,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onEditDescription,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      item.description != null &&
                          item.description!.trim().isNotEmpty
                      ? theme.colorScheme.surfaceContainerLow
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      item.description != null &&
                          item.description!.trim().isNotEmpty
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          item.description != null &&
                              item.description!.trim().isNotEmpty
                          ? Text(
                              item.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            )
                          : Text(
                              'Add description...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      item.description != null &&
                              item.description!.trim().isNotEmpty
                          ? Icons.edit_outlined
                          : Icons.add,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'Preview',
                  iconSize: 18,
                  onPressed: onPreview,
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_outlined),
                  tooltip: 'Open / Share',
                  iconSize: 18,
                  onPressed: onOpen,
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download',
                  iconSize: 18,
                  onPressed: onDownload,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  color: AppTheme.statusRed,
                  iconSize: 18,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

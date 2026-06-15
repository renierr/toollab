import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/image_metadata_extractor.dart';
import 'image_metadata_dialog.dart';

class ImageViewerEditor extends StatelessWidget {
  final TextEditingController widthController;
  final TextEditingController heightController;
  final bool keepAspectRatio;
  final ValueChanged<bool> onKeepAspectRatioChanged;
  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;
  final double quality;
  final ValueChanged<double> onQualityChanged;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool isProcessing;
  final String originalDimensions;
  final String originalSize;
  final ImageMetadata? metadata;
  final String fileName;
  final bool preserveExif;
  final ValueChanged<bool> onPreserveExifChanged;

  // Transform actions
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onFlipVertical;
  final VoidCallback onToggleCropMode;
  final bool isCropMode;
  final VoidCallback onToggleRedactMode;
  final bool isRedactMode;
  final bool isWideScreen;

  const ImageViewerEditor({
    super.key,
    required this.widthController,
    required this.heightController,
    required this.keepAspectRatio,
    required this.onKeepAspectRatioChanged,
    required this.selectedFormat,
    required this.onFormatChanged,
    required this.quality,
    required this.onQualityChanged,
    required this.onPreview,
    required this.onSave,
    required this.onShare,
    required this.isProcessing,
    required this.originalDimensions,
    required this.originalSize,
    required this.metadata,
    required this.fileName,
    required this.preserveExif,
    required this.onPreserveExifChanged,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onFlipHorizontal,
    required this.onFlipVertical,
    required this.onToggleCropMode,
    required this.isCropMode,
    required this.onToggleRedactMode,
    required this.isRedactMode,
    required this.isWideScreen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showQualitySlider =
        selectedFormat == 'jpg' || selectedFormat == 'webp';

    final dot = fileName.lastIndexOf('.');
    final fileFormat = (dot != -1 && dot < fileName.length - 1)
        ? fileName.substring(dot + 1).toUpperCase()
        : '';

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 16.0,
        top: isWideScreen ? 76.0 : 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Section
          const _SectionHeader(
            title: 'Original File Details',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (fileFormat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          fileFormat,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 16),
                _InfoRow(label: 'Dimensions', value: originalDimensions),
                const Divider(height: 16),
                _InfoRow(label: 'File Size', value: originalSize),
                if (metadata != null) ...[
                  const Divider(height: 16),
                  TextButton.icon(
                    onPressed: (isCropMode || isRedactMode)
                        ? null
                        : () => ImageMetadataDialog.show(
                            context: context,
                            metadata: metadata!,
                            fileName: fileName,
                          ),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('More Information'),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Transform Section
          const _SectionHeader(
            title: 'Transform',
            icon: Icons.transform_outlined,
          ),
          const SizedBox(height: 12),
          (isCropMode || isRedactMode)
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCropMode ? Icons.crop : Icons.blur_on,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isCropMode
                              ? 'Cropping Active. Adjust controls on the image display.'
                              : 'Redacting Active. Adjust controls on the image display.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton.outlined(
                      onPressed: onRotateLeft,
                      icon: const Icon(Icons.rotate_left),
                      tooltip: 'Rotate 90° Left',
                    ),
                    IconButton.outlined(
                      onPressed: onRotateRight,
                      icon: const Icon(Icons.rotate_right),
                      tooltip: 'Rotate 90° Right',
                    ),
                    IconButton.outlined(
                      onPressed: onFlipHorizontal,
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: 'Flip Horizontally',
                    ),
                    IconButton.outlined(
                      onPressed: onFlipVertical,
                      icon: const Icon(Icons.swap_vert),
                      tooltip: 'Flip Vertically',
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleCropMode,
                      icon: const Icon(Icons.crop),
                      label: const Text('Crop'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleRedactMode,
                      icon: const Icon(Icons.blur_on),
                      label: const Text('Redact'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // Disable other controls during crop/redact mode to keep user focused
          if (!isCropMode && !isRedactMode) ...[
            // Resize Section
            const _SectionHeader(
              title: 'Resize Image',
              icon: Icons.aspect_ratio_outlined,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: widthController,
                    decoration: const InputDecoration(
                      labelText: 'Width (px)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onKeepAspectRatioChanged(!keepAspectRatio),
                  icon: Icon(
                    keepAspectRatio ? Icons.link : Icons.link_off,
                    color: keepAspectRatio
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: keepAspectRatio
                      ? 'Aspect ratio locked'
                      : 'Aspect ratio unlocked',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    decoration: const InputDecoration(
                      labelText: 'Height (px)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview Button
            ElevatedButton.icon(
              onPressed: isProcessing ? null : onPreview,
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Preview Resize'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Format Section
            const _SectionHeader(
              title: 'Output Format',
              icon: Icons.image_search_outlined,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'png', child: Text('PNG (.png)')),
                DropdownMenuItem(value: 'jpg', child: Text('JPEG (.jpg)')),
                DropdownMenuItem(value: 'bmp', child: Text('BMP (.bmp)')),
              ],
              onChanged: (val) {
                if (val != null) onFormatChanged(val);
              },
            ),
            const SizedBox(height: 12),

            // EXIF Preserve Checkbox
            CheckboxListTile(
              title: const Text('Preserve EXIF Metadata'),
              subtitle: const Text(
                'Keep GPS, camera tags, and date (JPEG only)',
              ),
              value: preserveExif,
              onChanged: (val) {
                if (val != null) onPreserveExifChanged(val);
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 12),

            // Quality Slider (for JPG and WebP)
            if (showQualitySlider) ...[
              Text(
                'Compression Quality: ${quality.round()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Slider(
                value: quality,
                min: 10,
                max: 100,
                divisions: 90,
                label: '${quality.round()}%',
                onChanged: onQualityChanged,
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),

            // Action Buttons
            isProcessing
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share Image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value),
      ],
    );
  }
}

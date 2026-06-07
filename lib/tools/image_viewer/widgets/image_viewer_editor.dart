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
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool isProcessing;
  final String originalDimensions;
  final String originalSize;
  final ImageMetadata? metadata;
  final String fileName;
  final bool preserveExif;
  final ValueChanged<bool> onPreserveExifChanged;

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
    required this.onSave,
    required this.onShare,
    required this.isProcessing,
    required this.originalDimensions,
    required this.originalSize,
    required this.metadata,
    required this.fileName,
    required this.preserveExif,
    required this.onPreserveExifChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showQualitySlider =
        selectedFormat == 'jpg' || selectedFormat == 'webp';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
                _InfoRow(label: 'Dimensions', value: originalDimensions),
                const Divider(height: 16),
                _InfoRow(label: 'File Size', value: originalSize),
                if (metadata != null) ...[
                  const Divider(height: 16),
                  TextButton.icon(
                    onPressed: () => ImageMetadataDialog.show(
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
              DropdownMenuItem(value: 'webp', child: Text('WebP (.webp)')),
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
            subtitle: const Text('Keep GPS, camera tags, and date (JPEG only)'),
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

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class ImagePreviewDialog extends StatefulWidget {
  final ImageProvider image;
  final String? label;

  const ImagePreviewDialog({super.key, required this.image, this.label});

  static Future<void> show({
    required BuildContext context,
    required ImageProvider image,
    String? label,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => ImagePreviewDialog(image: image, label: label),
    );
  }

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  final _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _resetZoom() => _transformation.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTap: _resetZoom,
            child: InteractiveViewer(
              transformationController: _transformation,
              minScale: 1.0,
              maxScale: 8.0,
              child: Image(image: widget.image, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.75),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (widget.label != null && widget.label!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: theme.colorScheme.surface.withValues(alpha: 0.75),
                child: Text(
                  widget.label!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

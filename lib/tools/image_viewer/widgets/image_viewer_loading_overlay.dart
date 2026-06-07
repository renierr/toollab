import 'package:flutter/material.dart';

class ImageViewerLoadingOverlay extends StatelessWidget {
  final bool isVisible;

  const ImageViewerLoadingOverlay({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Card(
            color: theme.colorScheme.surface,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Processing Image...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Executing operations in background',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

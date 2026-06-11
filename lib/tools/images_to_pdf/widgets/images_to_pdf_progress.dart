import 'package:flutter/material.dart';
import 'package:tool_lab/tools/images_to_pdf/config.dart';

class ImagesToPdfProgress extends StatelessWidget {
  final double progress;
  final String statusText;

  const ImagesToPdfProgress({
    super.key,
    required this.progress,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ImagesToPdfTool.config.accentColor;
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  statusText,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.15),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

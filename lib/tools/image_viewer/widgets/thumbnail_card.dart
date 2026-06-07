import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/info_card.dart';

class ThumbnailCard extends StatelessWidget {
  final Uint8List thumbnailBytes;

  const ThumbnailCard({super.key, required this.thumbnailBytes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InfoCard(
      icon: Icons.photo_outlined,
      title: 'EXIF Embedded Thumbnail',
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 150, maxWidth: 200),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Image.memory(thumbnailBytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

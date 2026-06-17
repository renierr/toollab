import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

class ThumbnailCard extends StatelessWidget {
  final Uint8List thumbnailBytes;

  const ThumbnailCard({super.key, required this.thumbnailBytes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return InfoCard(
      icon: Icons.photo_outlined,
      title: l10n.imgViewExifThumbnailTitle,
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

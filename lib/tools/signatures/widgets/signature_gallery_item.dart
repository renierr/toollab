import 'package:flutter/material.dart';

import 'package:tool_lab/helpers/format_helper.dart';
import '../signature_models.dart';
import 'signature_background.dart';

/// A single saved-signature card with a transparency-aware preview and actions.
class SignatureGalleryItem extends StatelessWidget {
  final SignatureRecord record;
  final CanvasBackground background;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;

  const SignatureGalleryItem({
    super.key,
    required this.record,
    required this.background,
    required this.onLoad,
    required this.onDelete,
    required this.onExportPng,
    required this.onExportSvg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SignatureBackground(
              background: background,
              child: record.image == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.memory(record.image!, fit: BoxFit.contain),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              FormatHelper.epoch(record.updatedAt),
              style: theme.textTheme.labelSmall,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CompactIconButton(
                tooltip: 'Load',
                icon: Icons.edit_outlined,
                onPressed: onLoad,
              ),
              _CompactIconButton(
                tooltip: 'PNG',
                icon: Icons.image_outlined,
                onPressed: onExportPng,
              ),
              _CompactIconButton(
                tooltip: 'SVG',
                icon: Icons.polyline_outlined,
                onPressed: onExportSvg,
              ),
              _CompactIconButton(
                tooltip: 'Delete',
                icon: Icons.delete_outline,
                color: theme.colorScheme.error,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback onPressed;

  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }
}

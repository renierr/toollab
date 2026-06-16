import 'package:flutter/material.dart';

import '../signature_models.dart';

/// A single saved-signature card with a transparency-aware preview and actions.
class SignatureGalleryItem extends StatelessWidget {
  final SignatureRecord record;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;

  const SignatureGalleryItem({
    super.key,
    required this.record,
    required this.onLoad,
    required this.onDelete,
    required this.onExportPng,
    required this.onExportSvg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(record.updatedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _CheckerboardPainter(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
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
              '${date.year}-${_two(date.month)}-${_two(date.day)} '
              '${_two(date.hour)}:${_two(date.minute)}',
              style: theme.textTheme.labelSmall,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Load',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onLoad,
              ),
              IconButton(
                tooltip: 'PNG',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.image_outlined, size: 18),
                onPressed: onExportPng,
              ),
              IconButton(
                tooltip: 'SVG',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.polyline_outlined, size: 18),
                onPressed: onExportSvg,
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

class _CheckerboardPainter extends CustomPainter {
  final Color color;
  const _CheckerboardPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 10.0;
    final paint = Paint()..color = color;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = ((x ~/ cell) + (y ~/ cell)) % 2 == 0;
        if (even) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) =>
      oldDelegate.color != color;
}

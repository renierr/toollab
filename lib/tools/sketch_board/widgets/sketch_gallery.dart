import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/drawing_record.dart';
import '../sketch_board_state.dart';
import 'sketch_gallery_item.dart';

class SketchGallery extends StatelessWidget {
  final void Function(DrawingRecord record) onLoad;
  final void Function(DrawingRecord record) onDelete;

  const SketchGallery({
    super.key,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<SketchBoardState>(
      builder: (context, state, _) {
        final saved = state.saved;
        if (saved.isEmpty) {
          return Center(
            child: Text(
              l10n.sketchGalleryEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: 200,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: saved.length,
          itemBuilder: (context, i) {
            final record = saved[i];
            return SketchGalleryItem(
              record: record,
              onLoad: () => onLoad(record),
              onDelete: () => onDelete(record),
            );
          },
        );
      },
    );
  }
}

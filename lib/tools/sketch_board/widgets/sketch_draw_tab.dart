import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../sketch_board_state.dart';
import 'sketch_canvas.dart';
import 'sketch_properties_bar.dart';
import 'sketch_selection_actions.dart';
import 'sketch_toolbar.dart';

class SketchDrawTab extends StatelessWidget {
  const SketchDrawTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SketchBoardState>();
    final bounds = state.selectionBounds;

    return Stack(
      children: [
        const Positioned.fill(child: SketchCanvas()),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.topCenter,
                child: SketchPropertiesBar(),
              ),
              if (bounds != null && state.selectedIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _SelectionSizeBadge(bounds: bounds),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(child: SketchToolbar()),
        ),
        const Positioned(
          right: 12,
          bottom: 80,
          child: SketchSelectionActions(),
        ),
      ],
    );
  }
}

class _SelectionSizeBadge extends StatelessWidget {
  final Rect bounds;

  const _SelectionSizeBadge({required this.bounds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widthStr = bounds.width.toStringAsFixed(0);
    final heightStr = bounds.height.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.85,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_size_select_large_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '${widthStr}x$heightStr',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

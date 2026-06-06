import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';

class ToolFavoriteButton extends StatelessWidget {
  final String toolId;
  final double iconSize;

  const ToolFavoriteButton({
    super.key,
    required this.toolId,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isFav = appState.isFavorite(toolId);
    return IconButton(
      icon: Icon(
        isFav ? Icons.star : Icons.star_outline,
        size: iconSize,
        color: isFav
            ? AppTheme.favoriteStar
            : Theme.of(context).colorScheme.onSurface.withAlpha(100),
      ),
      onPressed: () => appState.toggleFavorite(toolId),
      visualDensity: VisualDensity.compact,
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
    );
  }
}

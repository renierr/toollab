import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/widgets/tool_favorite_button.dart';

class ToolCardCompact extends StatelessWidget {
  final ToolModel tool;
  final double cardWidth;

  const ToolCardCompact({
    super.key,
    required this.tool,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = cardWidth < 200;

    final horizontalPadding = isNarrow ? 8.0 : 12.0;
    final verticalPadding = isNarrow ? 8.0 : 10.0;
    final gapWidth = isNarrow ? 8.0 : 12.0;
    final iconPadding = isNarrow ? 6.0 : 8.0;
    final iconSize = isNarrow ? 18.0 : 20.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tool.accentColor, width: 3)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: tool.accentColor.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(tool.icon, size: iconSize, color: tool.accentColor),
            ),
            SizedBox(width: gapWidth),
            Expanded(
              child: Text(
                tool.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: isNarrow ? 13.0 : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ToolFavoriteButton(
              toolId: tool.id,
              iconSize: isNarrow ? 16.0 : 18.0,
            ),
            Icon(
              Icons.chevron_right,
              size: isNarrow ? 16.0 : 18.0,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }
}

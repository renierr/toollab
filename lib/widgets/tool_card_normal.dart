import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_favorite_button.dart';

class ToolCardNormal extends StatelessWidget {
  final ToolModel tool;
  final double cardWidth;

  const ToolCardNormal({
    super.key,
    required this.tool,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isNarrow = cardWidth < 200;
    final padding = isNarrow ? 8.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tool.accentColor, width: 3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isNarrow ? 6.0 : 8.0),
                  decoration: BoxDecoration(
                    color: tool.accentColor.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tool.icon,
                    size: isNarrow ? 18.0 : 22.0,
                    color: tool.accentColor,
                  ),
                ),
                const Spacer(),
                ToolFavoriteButton(
                  toolId: tool.id,
                  iconSize: isNarrow ? 16.0 : 18.0,
                ),
              ],
            ),
            SizedBox(height: isNarrow ? 6.0 : 8.0),
            Text(
              tool.localizedName(l10n),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isNarrow ? 13.0 : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                tool.localizedDescription(l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                  height: 1.3,
                  fontSize: isNarrow ? 11.0 : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
